-- MFA: atomic Super Admin agent application review.
-- This function is deliberately limited to listing verification; it never enables transactions.
create or replace function public.mfa_review_agent_application(
  p_agent_id uuid,
  p_action text,
  p_reason text default null,
  p_evidence_reference text default null
)
returns table (
  agent_id uuid,
  new_status text,
  event_type text
)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_actor uuid := (select auth.uid());
  v_aal text := (select auth.jwt() ->> 'aal');
  v_current_status text;
  v_new_status text;
  v_event_type text;
  v_reason text := nullif(left(trim(coalesce(p_reason, '')), 1000), '');
  v_evidence text := nullif(left(trim(coalesce(p_evidence_reference, '')), 1000), '');
begin
  if v_actor is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if v_aal is distinct from 'aal2' then
    raise exception 'Administrator MFA (AAL2) is required' using errcode = '42501';
  end if;

  if not exists (
    select 1 from public.profiles p
    where p.id = v_actor and p.role = 'super_admin'
  ) then
    raise exception 'Super Admin permission is required' using errcode = '42501';
  end if;

  if p_action not in ('approve', 'reject', 'request_information', 'suspend') then
    raise exception 'Unsupported review action' using errcode = '22023';
  end if;

  if p_action in ('reject', 'request_information', 'suspend') and v_reason is null then
    raise exception 'A reason is required for this action' using errcode = '22023';
  end if;

  select a.status into v_current_status
  from public.agent_profiles a
  where a.id = p_agent_id
  for update;

  if not found then
    raise exception 'Agent application not found' using errcode = 'P0002';
  end if;

  if p_action in ('approve', 'reject', 'request_information') and v_current_status <> 'pending' then
    raise exception 'Only pending applications can receive this decision' using errcode = '55000';
  end if;

  if p_action = 'suspend' and v_current_status <> 'verified' then
    raise exception 'Only verified agents can be suspended' using errcode = '55000';
  end if;

  v_new_status := case
    when p_action = 'approve' then 'verified'
    when p_action = 'reject' then 'rejected'
    when p_action = 'suspend' then 'suspended'
    else v_current_status
  end;

  v_event_type := case
    when p_action = 'approve' then 'approved'
    when p_action = 'reject' then 'rejected'
    when p_action = 'suspend' then 'suspended'
    else 'information_requested'
  end;

  update public.agent_profiles
  set status = v_new_status,
      transaction_enabled = false,
      updated_at = now()
  where id = p_agent_id;

  insert into public.agent_verification_events (
    agent_id, actor_id, event_type, reason, evidence_reference
  ) values (
    p_agent_id, v_actor, v_event_type, v_reason, v_evidence
  );

  return query select p_agent_id, v_new_status, v_event_type;
end;
$function$;

revoke all on function public.mfa_review_agent_application(uuid, text, text, text) from public;
revoke all on function public.mfa_review_agent_application(uuid, text, text, text) from anon;
grant execute on function public.mfa_review_agent_application(uuid, text, text, text) to authenticated;
