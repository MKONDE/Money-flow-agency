-- Money Flow Agency: isolated foundation schema.
-- Apply ONLY to the dedicated MFA Supabase project. Never run against CFG or another project.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  phone text,
  role text not null default 'customer'
    check (role in ('super_admin','country_manager','regional_manager','verified_agent','pending_agent','affiliate','business_partner','customer')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.agent_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  agent_type text not null default 'individual' check (agent_type in ('individual','business')),
  brand_name text not null,
  slug text not null unique,
  description text,
  country_code char(2) not null,
  region text,
  city text,
  service_address text,
  phone text,
  public_email text,
  website text,
  languages text[] not null default '{}',
  services text[] not null default '{}',
  payment_networks text[] not null default '{}',
  working_hours jsonb not null default '{}'::jsonb,
  logo_url text,
  profile_image_url text,
  status text not null default 'pending' check (status in ('pending','verified','suspended','rejected')),
  is_online boolean not null default false,
  transaction_enabled boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.agent_verification_events (
  id uuid primary key default gen_random_uuid(),
  agent_id uuid not null references public.agent_profiles(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  event_type text not null check (event_type in ('submitted','information_requested','approved','rejected','suspended','reinstated')),
  reason text,
  evidence_reference text,
  created_at timestamptz not null default now()
);

create table if not exists public.business_partners (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid references auth.users(id) on delete set null,
  legal_name text not null,
  display_name text not null,
  partner_type text not null default 'business',
  contract_status text not null default 'pending' check (contract_status in ('pending','under_review','approved','suspended','terminated')),
  country_code char(2),
  website text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  reference_code text not null unique,
  requester_id uuid references auth.users(id) on delete set null,
  partner_id uuid references public.business_partners(id) on delete set null,
  subject text not null,
  description text not null,
  status text not null default 'new' check (status in ('new','assigned','in_progress','resolved','closed')),
  assigned_to uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists agent_profiles_directory_idx
  on public.agent_profiles(status, country_code, region, city);
create index if not exists agent_profiles_brand_name_idx
  on public.agent_profiles using gin (to_tsvector('simple', brand_name));
create index if not exists support_tickets_status_idx on public.support_tickets(status, created_at desc);
create index if not exists audit_logs_created_at_idx on public.audit_logs(created_at desc);

create or replace function public.current_mfa_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid()
$$;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at before update on public.profiles
for each row execute function public.set_updated_at();

drop trigger if exists agent_profiles_set_updated_at on public.agent_profiles;
create trigger agent_profiles_set_updated_at before update on public.agent_profiles
for each row execute function public.set_updated_at();

create or replace function public.handle_mfa_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  agent_name text := nullif(trim(meta->>'brand_name'), '');
begin
  insert into public.profiles (id, full_name, phone, role)
  values (
    new.id,
    nullif(trim(meta->>'full_name'), ''),
    nullif(trim(meta->>'phone'), ''),
    'customer'
  ) on conflict (id) do nothing;

  if meta->>'account_type' = 'agent' and agent_name is not null then
    insert into public.agent_profiles (
      user_id, agent_type, brand_name, slug, description, country_code,
      region, city, service_address, phone, public_email, website,
      languages, services, payment_networks
    ) values (
      new.id,
      case when meta->>'agent_type' = 'business' then 'business' else 'individual' end,
      agent_name,
      trim(both '-' from regexp_replace(lower(agent_name), '[^a-z0-9]+', '-', 'g')) || '-' || substr(new.id::text, 1, 8),
      nullif(trim(meta->>'description'), ''),
      upper(coalesce(nullif(meta->>'country_code',''), 'TZ')),
      nullif(trim(meta->>'region'), ''),
      nullif(trim(meta->>'city'), ''),
      nullif(trim(meta->>'service_address'), ''),
      nullif(trim(meta->>'phone'), ''),
      new.email,
      nullif(trim(meta->>'website'), ''),
      coalesce(array(select jsonb_array_elements_text(coalesce(meta->'languages','[]'::jsonb))), '{}'),
      coalesce(array(select jsonb_array_elements_text(coalesce(meta->'services','[]'::jsonb))), '{}'),
      coalesce(array(select jsonb_array_elements_text(coalesce(meta->'payment_networks','[]'::jsonb))), '{}')
    ) on conflict (user_id) do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_mfa on auth.users;
create trigger on_auth_user_created_mfa
after insert on auth.users
for each row execute function public.handle_mfa_new_user();

alter table public.profiles enable row level security;
alter table public.agent_profiles enable row level security;
alter table public.agent_verification_events enable row level security;
alter table public.business_partners enable row level security;
alter table public.support_tickets enable row level security;
alter table public.audit_logs enable row level security;

-- Profiles: users can read their own profile. Only privileged staff can read all profiles.
drop policy if exists "profiles_read_self_or_admin" on public.profiles;
create policy "profiles_read_self_or_admin" on public.profiles
for select to authenticated
using (id = auth.uid() or public.current_mfa_role() = 'super_admin');

-- Do not grant users the ability to change their own role.
revoke all on public.profiles from anon;
grant select on public.profiles to authenticated;
revoke update on public.profiles from authenticated;
grant update (full_name, phone) on public.profiles to authenticated;
drop policy if exists "profiles_update_self" on public.profiles;
create policy "profiles_update_self" on public.profiles
for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- Directory: public visitors only see verified profiles. Owners see their own pending profile.
drop policy if exists "agent_profiles_public_verified" on public.agent_profiles;
create policy "agent_profiles_public_verified" on public.agent_profiles
for select to anon, authenticated using (status = 'verified');
drop policy if exists "agent_profiles_owner_read" on public.agent_profiles;
create policy "agent_profiles_owner_read" on public.agent_profiles
for select to authenticated using (user_id = auth.uid());
drop policy if exists "agent_profiles_admin_read" on public.agent_profiles;
create policy "agent_profiles_admin_read" on public.agent_profiles
for select to authenticated using (public.current_mfa_role() = 'super_admin');

-- Agents can update only profile/branding fields; role, status and transaction_enabled
-- are not granted for user updates and remain controlled by authorized admin workflows.
grant select on public.agent_profiles to anon, authenticated;
revoke update on public.agent_profiles from authenticated;
grant update (
  brand_name, description, region, city, service_address, phone, website,
  languages, working_hours, logo_url, profile_image_url, is_online
) on public.agent_profiles to authenticated;
drop policy if exists "agent_profiles_owner_update" on public.agent_profiles;
create policy "agent_profiles_owner_update" on public.agent_profiles
for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Explicit table privileges complement RLS; policies remain the row-level boundary.
grant select, insert on public.agent_verification_events to authenticated;
grant select, insert, update on public.business_partners to authenticated;
grant select, insert, update on public.support_tickets to authenticated;
grant select on public.audit_logs to authenticated;

-- Verification evidence and audit logs are never public.
drop policy if exists "verification_admin_read" on public.agent_verification_events;
create policy "verification_admin_read" on public.agent_verification_events
for select to authenticated using (public.current_mfa_role() = 'super_admin');
drop policy if exists "verification_admin_insert" on public.agent_verification_events;
create policy "verification_admin_insert" on public.agent_verification_events
for insert to authenticated with check (public.current_mfa_role() = 'super_admin');

drop policy if exists "partners_admin_all" on public.business_partners;
create policy "partners_admin_all" on public.business_partners
for all to authenticated using (public.current_mfa_role() = 'super_admin')
with check (public.current_mfa_role() = 'super_admin');

drop policy if exists "tickets_requester_read" on public.support_tickets;
create policy "tickets_requester_read" on public.support_tickets
for select to authenticated using (requester_id = auth.uid() or public.current_mfa_role() = 'super_admin');
drop policy if exists "tickets_requester_insert" on public.support_tickets;
create policy "tickets_requester_insert" on public.support_tickets
for insert to authenticated with check (requester_id = auth.uid());
drop policy if exists "tickets_admin_update" on public.support_tickets;
create policy "tickets_admin_update" on public.support_tickets
for update to authenticated using (public.current_mfa_role() = 'super_admin')
with check (public.current_mfa_role() = 'super_admin');

drop policy if exists "audit_admin_read" on public.audit_logs;
create policy "audit_admin_read" on public.audit_logs
for select to authenticated using (public.current_mfa_role() = 'super_admin');

grant execute on function public.current_mfa_role() to authenticated;
