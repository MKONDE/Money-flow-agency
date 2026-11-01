-- Keep agent presence status in the privacy-safe public directory projection.
alter table public.public_agent_directory
  add column if not exists is_online boolean not null default false;

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
      (id,brand_name,description,country_code,region,city,services,languages,logo_url,is_online,synced_at)
    values
      (new.id,new.brand_name,new.description,new.country_code,new.region,new.city,new.services,new.languages,new.logo_url,new.is_online,now())
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
after insert or update of brand_name,description,country_code,region,city,services,languages,logo_url,is_online,status
on public.agent_profiles
for each row execute function public.sync_public_agent_directory();

insert into public.public_agent_directory
  (id,brand_name,description,country_code,region,city,services,languages,logo_url,is_online,synced_at)
select id,brand_name,description,country_code,region,city,services,languages,logo_url,is_online,now()
from public.agent_profiles where status='verified'
on conflict(id) do update set is_online=excluded.is_online,synced_at=now();
