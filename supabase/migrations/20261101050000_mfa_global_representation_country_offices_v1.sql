-- MFA Global Representation & Country Offices V1
create table if not exists public.country_representatives (
 id uuid primary key default gen_random_uuid(), country_code char(2) not null,
 display_name text not null, title text not null, organization_name text,
 public_city text, public_region text, public_address text, public_phone text, public_email text,
 verification_status text not null default 'pending' check (verification_status in ('pending','verified','rejected')),
 status text not null default 'inactive' check (status in ('active','inactive','suspended')),
 appointed_by uuid references auth.users(id), appointed_at timestamptz, effective_from date, effective_to date,
 show_publicly boolean not null default false, internal_notes text, created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(), check (effective_to is null or effective_from is null or effective_to >= effective_from)
);
create table if not exists public.country_offices (
 id uuid primary key default gen_random_uuid(), country_code char(2) not null, office_name text not null,
 office_type text not null default 'country_office' check (office_type in ('head_office','country_office','regional_office','service_office')),
 region text, city text, public_address text, public_phone text, public_email text,
 verification_status text not null default 'pending' check (verification_status in ('pending','verified','rejected')),
 status text not null default 'inactive' check (status in ('active','inactive','suspended')),
 verified_by uuid references auth.users(id), verified_at timestamptz, show_publicly boolean not null default false,
 internal_notes text, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.agent_location_profiles (
 id uuid primary key default gen_random_uuid(), agent_id uuid not null unique references public.agent_profiles(id) on delete cascade,
 country_code char(2) not null, region text, district text, city text, ward text, neighbourhood text, service_address text,
 location_type text not null default 'business' check (location_type in ('business','service_point','residential')),
 service_areas text[] not null default '{}', public_listing_consent boolean not null default false,
 review_status text not null default 'pending' check (review_status in ('pending','approved','rejected')),
 reviewed_by uuid references auth.users(id), reviewed_at timestamptz, created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create table if not exists public.global_presence_audit_log (
 id bigint generated always as identity primary key, actor_id uuid references auth.users(id),
 record_type text not null check (record_type in ('country_representative','country_office','agent_location')),
 record_id uuid not null, action text not null, before_data jsonb, after_data jsonb, created_at timestamptz not null default now()
);
create index if not exists country_representatives_public_idx on public.country_representatives(country_code,status,verification_status,show_publicly);
create index if not exists country_offices_public_idx on public.country_offices(country_code,status,verification_status,show_publicly);
create index if not exists agent_location_review_idx on public.agent_location_profiles(review_status,country_code);
alter table public.country_representatives enable row level security;
alter table public.country_offices enable row level security;
alter table public.agent_location_profiles enable row level security;
alter table public.global_presence_audit_log enable row level security;
create policy "Public can view approved representatives" on public.country_representatives for select to anon, authenticated using (verification_status='verified' and status='active' and show_publicly=true);
create policy "Super admins manage representatives" on public.country_representatives for all to authenticated using (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='super_admin')) with check (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='super_admin'));
create policy "Public can view approved offices" on public.country_offices for select to anon, authenticated using (verification_status='verified' and status='active' and show_publicly=true);
create policy "Super admins manage offices" on public.country_offices for all to authenticated using (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='super_admin')) with check (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='super_admin'));
create policy "Agents read own location" on public.agent_location_profiles for select to authenticated using (exists(select 1 from public.agent_profiles a where a.id=agent_id and a.user_id=(select auth.uid())));
create policy "Agents submit own location" on public.agent_location_profiles for insert to authenticated with check (exists(select 1 from public.agent_profiles a where a.id=agent_id and a.user_id=(select auth.uid())));
create policy "Agents update own pending location" on public.agent_location_profiles for update to authenticated using (exists(select 1 from public.agent_profiles a where a.id=agent_id and a.user_id=(select auth.uid())) and review_status <> 'approved') with check (exists(select 1 from public.agent_profiles a where a.id=agent_id and a.user_id=(select auth.uid())) and review_status='pending');
create policy "Super admins manage agent locations" on public.agent_location_profiles for all to authenticated using (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='super_admin')) with check (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='super_admin'));
create policy "Super admins read presence audit" on public.global_presence_audit_log for select to authenticated using (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='super_admin'));
create policy "Super admins write presence audit" on public.global_presence_audit_log for insert to authenticated with check (actor_id=(select auth.uid()) and exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='super_admin'));
grant select on public.country_representatives, public.country_offices to anon, authenticated;
grant select, insert, update, delete on public.country_representatives, public.country_offices to authenticated;
grant select, insert, update on public.agent_location_profiles to authenticated;
grant select, insert on public.global_presence_audit_log to authenticated;
create or replace function public.set_global_presence_updated_at() returns trigger language plpgsql set search_path = '' as $$ begin new.updated_at = now(); return new; end $$;
create trigger country_representatives_updated_at before update on public.country_representatives for each row execute function public.set_global_presence_updated_at();
create trigger country_offices_updated_at before update on public.country_offices for each row execute function public.set_global_presence_updated_at();
create trigger agent_location_profiles_updated_at before update on public.agent_location_profiles for each row execute function public.set_global_presence_updated_at();
