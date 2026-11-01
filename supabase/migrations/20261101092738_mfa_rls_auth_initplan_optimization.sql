-- Performance-only RLS predicate optimization. Authorization semantics are unchanged.
drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles
for update to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

drop policy if exists agent_profiles_owner_read on public.agent_profiles;
create policy agent_profiles_owner_read on public.agent_profiles
for select to authenticated
using (user_id = (select auth.uid()));

drop policy if exists agent_profiles_owner_update on public.agent_profiles;
create policy agent_profiles_owner_update on public.agent_profiles
for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

drop policy if exists "Super admins manage representatives" on public.country_representatives;
create policy "Super admins manage representatives" on public.country_representatives
for all to authenticated
using (((select auth.jwt())->>'aal') = 'aal2' and exists (
  select 1 from public.profiles p
  where p.id = (select auth.uid()) and p.role = 'super_admin'
))
with check (((select auth.jwt())->>'aal') = 'aal2' and exists (
  select 1 from public.profiles p
  where p.id = (select auth.uid()) and p.role = 'super_admin'
));

drop policy if exists "Super admins manage offices" on public.country_offices;
create policy "Super admins manage offices" on public.country_offices
for all to authenticated
using (((select auth.jwt())->>'aal') = 'aal2' and exists (
  select 1 from public.profiles p
  where p.id = (select auth.uid()) and p.role = 'super_admin'
))
with check (((select auth.jwt())->>'aal') = 'aal2' and exists (
  select 1 from public.profiles p
  where p.id = (select auth.uid()) and p.role = 'super_admin'
));

drop policy if exists "Super admins manage agent locations" on public.agent_location_profiles;
create policy "Super admins manage agent locations" on public.agent_location_profiles
for all to authenticated
using (((select auth.jwt())->>'aal') = 'aal2' and exists (
  select 1 from public.profiles p
  where p.id = (select auth.uid()) and p.role = 'super_admin'
))
with check (((select auth.jwt())->>'aal') = 'aal2' and exists (
  select 1 from public.profiles p
  where p.id = (select auth.uid()) and p.role = 'super_admin'
));

drop policy if exists "Super admins read presence audit" on public.global_presence_audit_log;
create policy "Super admins read presence audit" on public.global_presence_audit_log
for select to authenticated
using (((select auth.jwt())->>'aal') = 'aal2' and exists (
  select 1 from public.profiles p
  where p.id = (select auth.uid()) and p.role = 'super_admin'
));

drop policy if exists "Super admins write presence audit" on public.global_presence_audit_log;
create policy "Super admins write presence audit" on public.global_presence_audit_log
for insert to authenticated
with check (
  actor_id = (select auth.uid())
  and ((select auth.jwt())->>'aal') = 'aal2'
  and exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role = 'super_admin'
  )
);
