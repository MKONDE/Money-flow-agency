-- Enforce AAL2 for Super Admin writes and keep private columns out of public directory reads.
drop policy if exists "Super admins manage representatives" on public.country_representatives;
create policy "Super admins manage representatives" on public.country_representatives for all to authenticated
using ((select auth.jwt()->>'aal')='aal2' and exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='super_admin'))
with check ((select auth.jwt()->>'aal')='aal2' and exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='super_admin'));
drop policy if exists "Super admins manage offices" on public.country_offices;
create policy "Super admins manage offices" on public.country_offices for all to authenticated
using ((select auth.jwt()->>'aal')='aal2' and exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='super_admin'))
with check ((select auth.jwt()->>'aal')='aal2' and exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='super_admin'));
drop policy if exists "Super admins manage agent locations" on public.agent_location_profiles;
create policy "Super admins manage agent locations" on public.agent_location_profiles for all to authenticated
using ((select auth.jwt()->>'aal')='aal2' and exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='super_admin'))
with check ((select auth.jwt()->>'aal')='aal2' and exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='super_admin'));
drop policy if exists "Super admins read presence audit" on public.global_presence_audit_log;
create policy "Super admins read presence audit" on public.global_presence_audit_log for select to authenticated
using ((select auth.jwt()->>'aal')='aal2' and exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='super_admin'));
drop policy if exists "Super admins write presence audit" on public.global_presence_audit_log;
create policy "Super admins write presence audit" on public.global_presence_audit_log for insert to authenticated
with check (actor_id=(select auth.uid()) and (select auth.jwt()->>'aal')='aal2' and exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='super_admin'));
revoke select on public.country_representatives, public.country_offices from anon, authenticated;
grant select (id,country_code,display_name,title,organization_name,public_city,public_region,public_address,public_phone,public_email,verification_status,status,effective_from,effective_to,show_publicly,created_at,updated_at) on public.country_representatives to anon, authenticated;
grant select (id,country_code,office_name,office_type,region,city,public_address,public_phone,public_email,verification_status,status,verified_at,show_publicly,created_at,updated_at) on public.country_offices to anon, authenticated;
grant select (id,agent_id,country_code,region,district,city,ward,neighbourhood,service_address,location_type,service_areas,public_listing_consent,review_status,reviewed_by,reviewed_at,created_at,updated_at) on public.agent_location_profiles to authenticated;
create index if not exists country_representatives_appointed_by_idx on public.country_representatives(appointed_by);
create index if not exists country_offices_verified_by_idx on public.country_offices(verified_by);
create index if not exists agent_location_profiles_reviewed_by_idx on public.agent_location_profiles(reviewed_by);
create index if not exists global_presence_audit_log_actor_id_idx on public.global_presence_audit_log(actor_id);
