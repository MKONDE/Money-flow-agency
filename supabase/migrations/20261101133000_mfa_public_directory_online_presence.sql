-- Privacy-safe public presence, supported payment networks and explicit contact consent.
alter table public.agent_profiles
  add column if not exists public_contact_consent boolean not null default false;
alter table public.public_agent_directory
  add column if not exists is_online boolean not null default false,
  add column if not exists payment_networks text[] not null default '{}',
  add column if not exists public_phone text,
  add column if not exists public_email text;

grant update(public_contact_consent) on public.agent_profiles to authenticated;

do $
begin
  if not exists(select 1 from pg_catalog.pg_constraint where conname='mfa_agent_logo_https_url_check'
    and conrelid='public.agent_profiles'::regclass) then
    alter table public.agent_profiles add constraint mfa_agent_logo_https_url_check
      check (logo_url is null or logo_url ~ '^https://[^[:space:]]+

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
      (id,brand_name,description,country_code,region,city,services,languages,logo_url,is_online,
       payment_networks,public_phone,public_email,synced_at)
    values
      (new.id,new.brand_name,new.description,new.country_code,new.region,new.city,new.services,new.languages,new.logo_url,
       new.is_online,new.payment_networks,
       case when new.public_contact_consent then new.phone else null end,
       case when new.public_contact_consent then new.public_email else null end,now())
    on conflict (id) do update set
      brand_name=excluded.brand_name,
      description=excluded.description,
      country_code=excluded.country_code,
      region=excluded.region,
      city=excluded.city,
      services=excluded.services,
      languages=excluded.languages,
      logo_url=excluded.logo_url,
      is_online=excluded.is_online,
      payment_networks=excluded.payment_networks,
      public_phone=excluded.public_phone,
      public_email=excluded.public_email,
      synced_at=now();
  else
    delete from public.public_agent_directory where id=new.id;
  end if;
  return new;
end;
$$;
revoke all on function public.sync_public_agent_directory() from public,anon,authenticated;

drop trigger if exists sync_public_agent_directory_trigger on public.agent_profiles;
create trigger sync_public_agent_directory_trigger
after insert or update of brand_name,description,country_code,region,city,services,languages,logo_url,
  is_online,payment_networks,public_contact_consent,phone,public_email,status
on public.agent_profiles
for each row execute function public.sync_public_agent_directory();

insert into public.public_agent_directory
  (id,brand_name,description,country_code,region,city,services,languages,logo_url,is_online,
   payment_networks,public_phone,public_email,synced_at)
select id,brand_name,description,country_code,region,city,services,languages,logo_url,is_online,
  payment_networks,case when public_contact_consent then phone else null end,
  case when public_contact_consent then public_email else null end,now()
from public.agent_profiles where status='verified'
on conflict(id) do update set
  is_online=excluded.is_online,
  payment_networks=excluded.payment_networks,
  public_phone=excluded.public_phone,
  public_email=excluded.public_email,
  synced_at=now();
);
  end if;
end;
$;

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
      (id,brand_name,description,country_code,region,city,services,languages,logo_url,is_online,
       payment_networks,public_phone,public_email,synced_at)
    values
      (new.id,new.brand_name,new.description,new.country_code,new.region,new.city,new.services,new.languages,new.logo_url,
       new.is_online,new.payment_networks,
       case when new.public_contact_consent then new.phone else null end,
       case when new.public_contact_consent then new.public_email else null end,now())
    on conflict (id) do update set
      brand_name=excluded.brand_name,
      description=excluded.description,
      country_code=excluded.country_code,
      region=excluded.region,
      city=excluded.city,
      services=excluded.services,
      languages=excluded.languages,
      logo_url=excluded.logo_url,
      is_online=excluded.is_online,
      payment_networks=excluded.payment_networks,
      public_phone=excluded.public_phone,
      public_email=excluded.public_email,
      synced_at=now();
  else
    delete from public.public_agent_directory where id=new.id;
  end if;
  return new;
end;
$$;
revoke all on function public.sync_public_agent_directory() from public,anon,authenticated;

drop trigger if exists sync_public_agent_directory_trigger on public.agent_profiles;
create trigger sync_public_agent_directory_trigger
after insert or update of brand_name,description,country_code,region,city,services,languages,logo_url,
  is_online,payment_networks,public_contact_consent,phone,public_email,status
on public.agent_profiles
for each row execute function public.sync_public_agent_directory();

insert into public.public_agent_directory
  (id,brand_name,description,country_code,region,city,services,languages,logo_url,is_online,
   payment_networks,public_phone,public_email,synced_at)
select id,brand_name,description,country_code,region,city,services,languages,logo_url,is_online,
  payment_networks,case when public_contact_consent then phone else null end,
  case when public_contact_consent then public_email else null end,now()
from public.agent_profiles where status='verified'
on conflict(id) do update set
  is_online=excluded.is_online,
  payment_networks=excluded.payment_networks,
  public_phone=excluded.public_phone,
  public_email=excluded.public_email,
  synced_at=now();
