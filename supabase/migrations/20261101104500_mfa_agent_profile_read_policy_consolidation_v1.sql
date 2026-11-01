drop policy if exists agent_profiles_admin_read on public.agent_profiles;
drop policy if exists agent_profiles_owner_read on public.agent_profiles;

create policy agent_profiles_admin_or_owner_read
on public.agent_profiles
for select
to authenticated
using (
  private.current_mfa_role() = 'super_admin'
  or user_id = (select auth.uid())
);
