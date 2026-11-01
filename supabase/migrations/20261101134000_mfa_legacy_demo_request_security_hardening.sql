-- Least-privilege hardening for the legacy demo service-request workflow.
-- The live MFA database has these tables; on a clean install without the optional legacy
-- service-request tables, this migration safely skips their table-specific policies/grants.

create or replace function private.mfa_guard_legacy_service_request_update()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare
  v_agent_id uuid;
  v_agent_status text;
  v_admin boolean := private.current_mfa_role()='super_admin' and (select auth.jwt()->>'aal')='aal2';
begin
  if v_admin then return new; end if;

  if old.demo_only is not true or new.demo_only is not true then
    raise exception 'Only demo service requests are supported in MFA V1' using errcode='42501';
  end if;
  if (to_jsonb(new)-'request_status'-'updated_at') is distinct from (to_jsonb(old)-'request_status'-'updated_at') then
    raise exception 'Agents may only update the assigned demo request status' using errcode='42501';
  end if;

  select id,status into v_agent_id,v_agent_status
  from public.agent_profiles where user_id=auth.uid();
  if v_agent_id is null or v_agent_id is distinct from old.assigned_agent_id or v_agent_status is distinct from 'verified' then
    raise exception 'Verified assigned agent permission required' using errcode='42501';
  end if;

  if not (
    (old.request_status='assigned' and new.request_status in ('accepted','rejected'))
    or (old.request_status='accepted' and new.request_status='in_progress')
    or (old.request_status='in_progress' and new.request_status in ('awaiting_partner','completed'))
    or (old.request_status='awaiting_partner' and new.request_status in ('in_progress','completed'))
  ) then
    raise exception 'Invalid service request status transition' using errcode='22023';
  end if;
  new.updated_at:=now();
  return new;
end;
$$;
revoke all on function private.mfa_guard_legacy_service_request_update() from public,anon,authenticated;

-- Keep the agent RPC as SECURITY INVOKER. RLS and a private trigger enforce ownership and transitions.
create or replace function public.agent_update_service_request(
  p_request_id uuid,
  p_new_status text,
  p_note text default null
)
returns void
language plpgsql
security invoker
set search_path=''
as $$
declare
  v_agent_id uuid;
  v_current_status text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode='42501';
  end if;

  select ap.id into v_agent_id
  from public.agent_profiles ap
  where ap.user_id=auth.uid() and ap.status='verified';

  if v_agent_id is null then
    raise exception 'Verified agent profile required' using errcode='42501';
  end if;

  select sr.request_status into v_current_status
  from public.service_requests sr
  where sr.id=p_request_id and sr.assigned_agent_id=v_agent_id and sr.demo_only=true
  for update;

  if v_current_status is null then
    raise exception 'Request not found or not assigned to this agent' using errcode='P0002';
  end if;

  if not (
    (v_current_status='assigned' and p_new_status in ('accepted','rejected'))
    or (v_current_status='accepted' and p_new_status='in_progress')
    or (v_current_status='in_progress' and p_new_status in ('awaiting_partner','completed'))
    or (v_current_status='awaiting_partner' and p_new_status in ('in_progress','completed'))
  ) then
    raise exception 'Invalid request status transition' using errcode='22023';
  end if;

  update public.service_requests set request_status=p_new_status where id=p_request_id;

  insert into public.service_request_events(request_id,actor_id,actor_type,event_type,status,note)
  values(p_request_id,auth.uid(),'agent','agent_status_update',p_new_status,left(coalesce(p_note,''),1000));
end;
$$;
revoke all on function public.agent_update_service_request(uuid,text,text) from public,anon;
grant execute on function public.agent_update_service_request(uuid,text,text) to authenticated;

do $$
begin
  if to_regclass('public.service_requests') is not null then
    execute 'revoke all on public.service_requests from anon';
    execute 'revoke update on public.service_requests from authenticated';
    execute 'grant update(request_status,assigned_agent_id) on public.service_requests to authenticated';

    execute 'drop policy if exists service_requests_admin_update on public.service_requests';
    execute 'create policy service_requests_admin_update on public.service_requests for update to authenticated using ((select private.current_mfa_role())=''super_admin'' and (select auth.jwt()->>''aal'')=''aal2'') with check ((select private.current_mfa_role())=''super_admin'' and (select auth.jwt()->>''aal'')=''aal2'')';

    execute 'drop policy if exists service_requests_assigned_agent_update on public.service_requests';
    execute 'create policy service_requests_assigned_agent_update on public.service_requests for update to authenticated using (demo_only=true and exists(select 1 from public.agent_profiles ap where ap.id=assigned_agent_id and ap.user_id=(select auth.uid()) and ap.status=''verified'')) with check (demo_only=true and exists(select 1 from public.agent_profiles ap where ap.id=assigned_agent_id and ap.user_id=(select auth.uid()) and ap.status=''verified''))';

    execute 'drop trigger if exists mfa_guard_legacy_service_request_update on public.service_requests';
    execute 'create trigger mfa_guard_legacy_service_request_update before update on public.service_requests for each row execute function private.mfa_guard_legacy_service_request_update()';
  end if;

  if to_regclass('public.service_request_events') is not null then
    execute 'revoke all on public.service_request_events from anon';
    execute 'revoke update,delete on public.service_request_events from authenticated';
    execute 'grant select,insert on public.service_request_events to authenticated';
    execute 'drop policy if exists request_events_admin_all on public.service_request_events';
    execute 'create policy request_events_admin_all on public.service_request_events for all to authenticated using ((select private.current_mfa_role())=''super_admin'' and (select auth.jwt()->>''aal'')=''aal2'') with check ((select private.current_mfa_role())=''super_admin'' and (select auth.jwt()->>''aal'')=''aal2'')';
  end if;
end;
$$;
