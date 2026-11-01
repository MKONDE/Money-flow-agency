-- Initial privacy-safe public agent directory projection.
-- The projection is replaced by an RLS-protected table in the following migration.
create or replace view public.public_agent_directory
with (security_barrier = true)
as
select id, brand_name, description, country_code, region, city, services, languages, logo_url
from public.agent_profiles
where status = 'verified';

revoke all on public.public_agent_directory from public;
grant select on public.public_agent_directory to anon, authenticated;
drop policy if exists agent_profiles_public_verified on public.agent_profiles;
revoke all privileges on table public.agent_profiles from anon;
