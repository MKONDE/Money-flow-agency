-- MFA agent verification workflow V1.
-- Super Admin-only RPC. Keeps transaction permissions disabled regardless of verification outcome.
create or replace function public.mfa_review_agent_application(
  p_agent_id uuid,
  p_action text,
  p_reason text default null,
  p_evidence_reference text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_agent_user_id uuid;
  v_current_status text;
  v_next_status text;
  v_event_type text;
  v_reason text := nullif(trim(coalesce(p_reason, '')), '');
  v_evidence text := nullif(trim(coalesce(p_evidence_reference, '')), '');
begin
  if v_actor is null or (select auth.jwt())->>'aal' <> 'aal2' then
    raise exception 'AAL2 administrator session required' using errcode = '42501';
  end if;
  if private.current_mfa_role() is distinct from 'super_admin' then
    raise exception 'Super Admin permission required' using errcode = '42501';
  end if;
  if p_action not in ('approve', 'reject', 'request_information', 'suspend') then
    raise exception 'Unsupported agent review action' using errcode = '22023';
  end if;
  if p_action in ('reject', 'request_information', 'suspend') and v_reason is null then
    raise exception 'A decision reason is required for this action' using errcode = '22023';
  end if;
  if length(coalesce(v_reason, '')) > 1000 or length(coalesce(v_evidence, '')) > 1000 then
    raise exception 'Review details exceed the permitted length' using errcode = '22023';
  end if;

  select a.user_id, a.status into v_agent_user_id, v_current_status
  from public.agent_profiles a
  where a.id = p_agent_id
  for update;

  if not found then
    raise exception 'Agent application not found' using errcode = 'P0002';
  end if;

  if v_current_status in ('rejected', 'suspended') and p_action = 'approve' then
    raise exception 'Rejected or suspended applications require a separate reinstatement process' using errcode = '22023';
  end if;

  if p_action = 'approve' then
    v_next_status := 'verified';
    v_event_type := 'approved';
  elsif p_action = 'reject' then
    v_next_status := 'rejected';
    v_event_type := 'rejected';
  elsif p_action = 'suspend' then
    v_next_status := 'suspended';
    v_event_type := 'suspended';
  else
    v_next_status := 'pending';
    v_event_type := 'information_requested';
  end if;

  update public.agent_profiles
  set status = v_next_status,
      transaction_enabled = false,
      updated_at = now()
  where id = p_agent_id;

  if p_action = 'approve' then
    update public.profiles set role = 'verified_agent', updated_at = now()
    where id = v_agent_user_id;
  elsif p_action in ('reject', 'suspend') then
    update public.profiles set role = 'pending_agent', updated_at = now()
    where id = v_agent_user_id;
  end if;

  insert into public.agent_verification_events
    (agent_id, actor_id, event_type, reason, evidence_reference)
  values
    (p_agent_id, v_actor, v_event_type, v_reason, v_evidence);

  insert into public.audit_logs
    (actor_id, action, entity_type, entity_id, metadata)
  values
    (v_actor, 'agent_application_' || p_action, 'agent_profile', p_agent_id::text,
     jsonb_build_object('previous_status', v_current_status,
                        'new_status', v_next_status,
                        'reason', v_reason,
                        'evidence_reference', v_evidence,
                        'transaction_enabled', false));
end;
$$;

revoke all on function public.mfa_review_agent_application(uuid, text, text, text) from public, anon;
grant execute on function public.mfa_review_agent_application(uuid, text, text, text) to authenticated;
