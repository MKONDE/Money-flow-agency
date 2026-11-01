-- Replace the owner-executed view with a separately stored, RLS-protected
-- public projection. This avoids bypassing base-table RLS at query time.
drop view if exists public.public_agent_directory;

create table if not exists public.public_agent_directory (
  id uuid primary key references public.agent_profiles(id) on delete cascade,
  brand_name text not null,
  description text,
  country_code text not null,
  region text,
  city text,
  services text[],
  languages text[],
  logo_url text,
  synced_at timestamptz not null default now()
);

alter table public.public_agent_directory enable row level security;
revoke all on public.public_agent_directory from public;
grant select on public.public_agent_directory to anon, authenticated;

drop policy if exists public_agent_directory_read on public.public_agent_directory;
create policy public_agent_directory_read
on public.public_agent_directory
for select
to anon, authenticated
using (true);

create or replace function public.sync_public_agent_directory()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    delete from public.public_agent_directory where id = old.id;
    return old;
  end if;

  if new.status = 'verified' then
    insert into public.public_agent_directory
      (id, brand_name, description, country_code, region, city, services, languages, logo_url, synced_at)
    values
      (new.id, new.brand_name, new.description, new.country_code, new.region, new.city, new.services, new.languages, new.logo_url, now())
    on conflict (id) do update set
      brand_name = excluded.brand_name,
      description = excluded.description,
      country_code = excluded.country_code,
      region = excluded.region,
      city = excluded.city,
      services = excluded.services,
      languages = excluded.languages,
      logo_url = excluded.logo_url,
      synced_at = now();
  else
    delete from public.public_agent_directory where id = new.id;
  end if;
  return new;
end;
$$;

revoke all on function public.sync_public_agent_directory() from public, anon, authenticated;

drop trigger if exists sync_public_agent_directory_trigger on public.agent_profiles;
create trigger sync_public_agent_directory_trigger
after insert or update of brand_name, description, country_code, region, city, services, languages, logo_url, status
on public.agent_profiles
for each row execute function public.sync_public_agent_directory();

insert into public.public_agent_directory
  (id, brand_name, description, country_code, region, city, services, languages, logo_url, synced_at)
select id, brand_name, description, country_code, region, city, services, languages, logo_url, now()
from public.agent_profiles
where status = 'verified'
on conflict (id) do update set
  brand_name = excluded.brand_name,
  description = excluded.description,
  country_code = excluded.country_code,
  region = excluded.region,
  city = excluded.city,
  services = excluded.services,
  languages = excluded.languages,
  logo_url = excluded.logo_url,
  synced_at = now();
