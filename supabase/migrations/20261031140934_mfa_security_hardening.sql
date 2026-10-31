-- Harden MFA helper functions: keep privileged helpers out of the exposed API schema.
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create or replace function private.current_mfa_role()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select p.role from public.profiles as p where p.id = (select auth.uid())
$$;

revoke all on function private.current_mfa_role() from public, anon;
grant execute on function private.current_mfa_role() to authenticated;

drop policy if exists "profiles_read_self_or_admin" on public.profiles;
create policy "profiles_read_self_or_admin" on public.profiles
for select to authenticated
using (id = (select auth.uid()) or private.current_mfa_role() = 'super_admin');

drop policy if exists "agent_profiles_admin_read" on public.agent_profiles;
create policy "agent_profiles_admin_read" on public.agent_profiles
for select to authenticated using (private.current_mfa_role() = 'super_admin');

drop policy if exists "verification_admin_read" on public.agent_verification_events;
create policy "verification_admin_read" on public.agent_verification_events
for select to authenticated using (private.current_mfa_role() = 'super_admin');
drop policy if exists "verification_admin_insert" on public.agent_verification_events;
create policy "verification_admin_insert" on public.agent_verification_events
for insert to authenticated with check (private.current_mfa_role() = 'super_admin');

drop policy if exists "partners_admin_all" on public.business_partners;
create policy "partners_admin_all" on public.business_partners
for all to authenticated using (private.current_mfa_role() = 'super_admin')
with check (private.current_mfa_role() = 'super_admin');

drop policy if exists "tickets_requester_read" on public.support_tickets;
create policy "tickets_requester_read" on public.support_tickets
for select to authenticated using (requester_id = (select auth.uid()) or private.current_mfa_role() = 'super_admin');
drop policy if exists "tickets_requester_insert" on public.support_tickets;
create policy "tickets_requester_insert" on public.support_tickets
for insert to authenticated with check (requester_id = (select auth.uid()));
drop policy if exists "tickets_admin_update" on public.support_tickets;
create policy "tickets_admin_update" on public.support_tickets
for update to authenticated using (private.current_mfa_role() = 'super_admin')
with check (private.current_mfa_role() = 'super_admin');

drop policy if exists "audit_admin_read" on public.audit_logs;
create policy "audit_admin_read" on public.audit_logs
for select to authenticated using (private.current_mfa_role() = 'super_admin');

-- The trigger function is only invoked by the auth.users trigger, never as an API RPC.
revoke all on function public.handle_mfa_new_user() from public, anon, authenticated;
revoke all on function public.current_mfa_role() from public, anon, authenticated;

create index if not exists agent_verification_events_actor_id_idx on public.agent_verification_events(actor_id);
create index if not exists agent_verification_events_agent_id_idx on public.agent_verification_events(agent_id);
create index if not exists audit_logs_actor_id_idx on public.audit_logs(actor_id);
create index if not exists business_partners_owner_user_id_idx on public.business_partners(owner_user_id);
create index if not exists support_tickets_assigned_to_idx on public.support_tickets(assigned_to);
create index if not exists support_tickets_partner_id_idx on public.support_tickets(partner_id);
create index if not exists support_tickets_requester_id_idx on public.support_tickets(requester_id);
