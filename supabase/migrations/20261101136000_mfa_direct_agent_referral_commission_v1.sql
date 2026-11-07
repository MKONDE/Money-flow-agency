-- MFA V1 direct-agent referral commission: additive, non-payable accounting only.
-- Referral reward is funded only from the MFA company share of the commission pool.
-- No CFG connection, wallet, custody, settlement or payout is created.

alter table public.agent_profiles
  add column if not exists referral_code text,
  add column if not exists referred_by_agent_id uuid references public.agent_profiles(id) on delete set null,
  add column if not exists referral_activated_at timestamptz,
  add column if not exists referral_duration_months integer;

create or replace function private.mfa_generate_agent_referral_code()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.referral_code is null or length(trim(new.referral_code)) = 0 then
    new.referral_code := 'MFA-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10));
  end if;
  return new;
end;
$$;
revoke all on function private.mfa_generate_agent_referral_code() from public, anon, authenticated;
drop trigger if exists mfa_agent_referral_code_generate on public.agent_profiles;
create trigger mfa_agent_referral_code_generate
before insert on public.agent_profiles
for each row execute function private.mfa_generate_agent_referral_code();

update public.agent_profiles
set referral_code = 'MFA-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10))
where referral_code is null or length(trim(referral_code)) = 0;
create unique index if not exists agent_profiles_referral_code_uidx
  on public.agent_profiles(referral_code);
create index if not exists agent_profiles_referred_by_idx
  on public.agent_profiles(referred_by_agent_id) where referred_by_agent_id is not null;

create or replace function private.mfa_guard_agent_referral_attribution()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.referral_code is distinct from old.referral_code then
    raise exception 'Agent referral code is immutable' using errcode = '42501';
  end if;
  if new.referred_by_agent_id is distinct from old.referred_by_agent_id then
    if old.referred_by_agent_id is null and new.referred_by_agent_id is not null
      and pg_trigger_depth() > 1 then
      null; -- one-time assignment by the trusted auth-user referral capture trigger
    else
      raise exception 'Agent inviter attribution is immutable' using errcode = '42501';
    end if;
  end if;
  if old.referral_duration_months is not null and new.referral_duration_months is distinct from old.referral_duration_months then
    raise exception 'Referral duration snapshot is immutable' using errcode = '42501';
  end if;
  if old.referral_activated_at is not null and new.referral_activated_at is distinct from old.referral_activated_at then
    raise exception 'Referral activation date is immutable' using errcode = '42501';
  end if;
  return new;
end;
$$;
revoke all on function private.mfa_guard_agent_referral_attribution() from public, anon, authenticated;
drop trigger if exists mfa_agent_referral_attribution_guard on public.agent_profiles;
create trigger mfa_agent_referral_attribution_guard
before update of referral_code, referred_by_agent_id, referral_activated_at on public.agent_profiles
for each row execute function private.mfa_guard_agent_referral_attribution();

create or replace function private.mfa_capture_agent_referral()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_code text := upper(trim(coalesce(new.raw_user_meta_data->>'referral_code', '')));
  v_agent_id uuid;
  v_referrer_id uuid;
begin
  if coalesce(new.raw_user_meta_data->>'account_type', '') <> 'agent' or v_code = '' then
    return new;
  end if;
  select id into v_agent_id from public.agent_profiles where user_id = new.id;
  if v_agent_id is null then
    raise exception 'Agent profile was not created before referral attribution' using errcode = '23514';
  end if;
  select a.id into v_referrer_id
  from public.agent_profiles a
  join public.mfa_agent_cfg_supply s on s.agent_id = a.id
  where a.referral_code = v_code
    and a.user_id <> new.id
    and a.status = 'verified'
    and s.verification_status = 'verified'
    and s.verified_supply_usd >= 50
  for share;
  if v_referrer_id is null then
    raise exception 'Referral code is invalid or the referring agent is not operationally active' using errcode = '22023';
  end if;
  update public.agent_profiles
  set referred_by_agent_id = v_referrer_id
  where id = v_agent_id and referred_by_agent_id is null;
  if not found then
    raise exception 'Referral attribution could not be recorded' using errcode = '23514';
  end if;
  return new;
end;
$$;
revoke all on function private.mfa_capture_agent_referral() from public, anon, authenticated;
drop trigger if exists zz_mfa_capture_agent_referral on auth.users;
create trigger zz_mfa_capture_agent_referral
after insert on auth.users
for each row execute function private.mfa_capture_agent_referral();

create or replace function private.mfa_set_referral_activation()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_agent_id uuid;
  v_duration_months integer;
begin
  if tg_table_name = 'agent_profiles' then
    v_agent_id := new.id;
  else
    v_agent_id := new.agent_id;
  end if;
  select duration_months into v_duration_months
  from public.mfa_referral_commission_settings where singleton = true;
  update public.agent_profiles a
  set referral_activated_at = now(),
      referral_duration_months = coalesce(v_duration_months, 12)
  where a.id = v_agent_id
    and a.referral_activated_at is null
    and a.status = 'verified'
    and exists (
      select 1 from public.mfa_agent_cfg_supply s
      where s.agent_id = a.id
        and s.verification_status = 'verified'
        and s.verified_supply_usd >= 50
    );
  return new;
end;
$$;
revoke all on function private.mfa_set_referral_activation() from public, anon, authenticated;
drop trigger if exists mfa_referral_activation_agent on public.agent_profiles;
create trigger mfa_referral_activation_agent
after update of status on public.agent_profiles
for each row execute function private.mfa_set_referral_activation();
drop trigger if exists mfa_referral_activation_supply on public.mfa_agent_cfg_supply;
create trigger mfa_referral_activation_supply
after insert or update of verification_status, verified_supply_usd on public.mfa_agent_cfg_supply
for each row execute function private.mfa_set_referral_activation();

create table public.mfa_referral_commission_settings (
  singleton boolean primary key default true check (singleton),
  company_share_reward_pct numeric(7,4) not null default 10
    check (company_share_reward_pct >= 0 and company_share_reward_pct <= 100),
  duration_months integer not null default 12 check (duration_months between 1 and 36),
  enabled boolean not null default true,
  effective_from timestamptz not null default now(),
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now()
);
insert into public.mfa_referral_commission_settings(singleton, company_share_reward_pct, duration_months, enabled)
values (true, 10, 12, true)
on conflict (singleton) do nothing;

create table public.mfa_referral_commission_history (
  id bigint generated always as identity primary key,
  company_share_reward_pct numeric(7,4) not null,
  duration_months integer not null,
  enabled boolean not null,
  actor_id uuid references auth.users(id),
  effective_from timestamptz not null,
  recorded_at timestamptz not null default now()
);

create table public.mfa_referral_commission_entries (
  id uuid primary key default gen_random_uuid(),
  commission_entry_id uuid not null unique references public.mfa_commission_entries(id) on delete restrict,
  transaction_id uuid not null unique references public.mfa_transactions(id) on delete restrict,
  referrer_agent_id uuid not null references public.agent_profiles(id) on delete restrict,
  referred_agent_id uuid not null references public.agent_profiles(id) on delete restrict,
  currency char(3) not null,
  commission_pool numeric(20,2) not null check (commission_pool >= 0),
  company_revenue numeric(20,2) not null check (company_revenue >= 0),
  company_share_reward_pct numeric(7,4) not null check (company_share_reward_pct between 0 and 100),
  referral_commission numeric(20,2) not null check (referral_commission >= 0 and referral_commission <= company_revenue),
  company_revenue_after_referral numeric(20,2) not null check (company_revenue_after_referral >= 0),
  activated_at timestamptz not null,
  eligible_until timestamptz not null,
  rule_snapshot jsonb not null,
  calculated_at timestamptz not null default now(),
  payable boolean not null default false check (payable = false),
  check (referrer_agent_id <> referred_agent_id),
  check (eligible_until > activated_at)
);

alter table public.mfa_referral_commission_settings enable row level security;
alter table public.mfa_referral_commission_history enable row level security;
alter table public.mfa_referral_commission_entries enable row level security;

create policy mfa_referral_settings_admin_read on public.mfa_referral_commission_settings
for select to authenticated
using ((select private.current_mfa_role()) = 'super_admin' and (select auth.jwt()->>'aal') = 'aal2');
create policy mfa_referral_history_admin_read on public.mfa_referral_commission_history
for select to authenticated
using ((select private.current_mfa_role()) = 'super_admin' and (select auth.jwt()->>'aal') = 'aal2');
create policy mfa_referral_entries_owner_read on public.mfa_referral_commission_entries
for select to authenticated
using (
  exists (select 1 from public.agent_profiles a
    where a.id = referrer_agent_id and a.user_id = (select auth.uid()))
);
create policy mfa_referral_entries_admin_read on public.mfa_referral_commission_entries
for select to authenticated
using ((select private.current_mfa_role()) = 'super_admin' and (select auth.jwt()->>'aal') = 'aal2');

revoke all on public.mfa_referral_commission_settings,
  public.mfa_referral_commission_history, public.mfa_referral_commission_entries
from public, anon, authenticated;
grant select on public.mfa_referral_commission_settings,
  public.mfa_referral_commission_history, public.mfa_referral_commission_entries to authenticated;

create or replace function public.mfa_update_referral_commission_settings(
  p_company_share_reward_pct numeric,
  p_duration_months integer,
  p_enabled boolean
)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_actor uuid := auth.uid();
  v_effective_from timestamptz := now();
begin
  if v_actor is null or coalesce((select auth.jwt())->>'aal', '') <> 'aal2'
    or private.current_mfa_role() is distinct from 'super_admin' then
    raise exception 'AAL2 Super Admin session required' using errcode = '42501';
  end if;
  if p_company_share_reward_pct is null or p_company_share_reward_pct < 0
    or p_company_share_reward_pct > 100 or p_duration_months is null
    or p_duration_months < 1 or p_duration_months > 36 or p_enabled is null then
    raise exception 'Invalid referral commission settings' using errcode = '22023';
  end if;
  insert into public.mfa_referral_commission_history(
    company_share_reward_pct, duration_months, enabled, actor_id, effective_from
  )
  select company_share_reward_pct, duration_months, enabled, v_actor, effective_from
  from public.mfa_referral_commission_settings where singleton = true;
  update public.mfa_referral_commission_settings
  set company_share_reward_pct = p_company_share_reward_pct,
      duration_months = p_duration_months,
      enabled = p_enabled,
      effective_from = v_effective_from,
      updated_by = v_actor,
      updated_at = v_effective_from
  where singleton = true;
  insert into public.audit_logs(actor_id, action, entity_type, entity_id, metadata)
  values (v_actor, 'referral_commission_settings_updated', 'mfa_referral_commission_settings', 'true',
    jsonb_build_object('company_share_reward_pct', p_company_share_reward_pct,
      'duration_months', p_duration_months, 'enabled', p_enabled));
end;
$$;
revoke all on function public.mfa_update_referral_commission_settings(numeric, integer, boolean) from public, anon;
grant execute on function public.mfa_update_referral_commission_settings(numeric, integer, boolean) to authenticated;

create or replace function private.mfa_create_referral_commission_entry()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_referred public.agent_profiles%rowtype;
  v_referrer public.agent_profiles%rowtype;
  v_setting public.mfa_referral_commission_settings%rowtype;
  v_reward numeric(20,2);
  v_eligible_until timestamptz;
begin
  select * into v_referred from public.agent_profiles where id = new.agent_id;
  if not found or v_referred.referred_by_agent_id is null or v_referred.referral_activated_at is null then
    return new;
  end if;
  select * into v_referrer from public.agent_profiles where id = v_referred.referred_by_agent_id;
  if not found or v_referrer.status <> 'verified' then return new; end if;
  if not exists (select 1 from public.mfa_agent_cfg_supply s
    where s.agent_id = v_referrer.id and s.verification_status = 'verified' and s.verified_supply_usd >= 50)
    or not exists (select 1 from public.mfa_agent_cfg_supply s
    where s.agent_id = v_referred.id and s.verification_status = 'verified' and s.verified_supply_usd >= 50)
    or v_referred.status <> 'verified' then
    return new;
  end if;
  select * into v_setting from public.mfa_referral_commission_settings where singleton = true;
  if not found or not v_setting.enabled or now() < v_referred.referral_activated_at then return new; end if;
  v_eligible_until := v_referred.referral_activated_at + make_interval(months => coalesce(v_referred.referral_duration_months, 12));
  if now() >= v_eligible_until or new.company_revenue <= 0 then return new; end if;
  v_reward := round(new.company_revenue * v_setting.company_share_reward_pct / 100, 2);
  if v_reward <= 0 then return new; end if;
  insert into public.mfa_referral_commission_entries(
    commission_entry_id, transaction_id, referrer_agent_id, referred_agent_id, currency,
    commission_pool, company_revenue, company_share_reward_pct, referral_commission,
    company_revenue_after_referral, activated_at, eligible_until, rule_snapshot, payable
  ) values (
    new.id, new.transaction_id, v_referrer.id, v_referred.id, new.currency,
    new.commission_pool, new.company_revenue, v_setting.company_share_reward_pct, v_reward,
    new.company_revenue - v_reward, v_referred.referral_activated_at, v_eligible_until,
    jsonb_build_object('basis', 'company_revenue', 'company_share_reward_pct', v_setting.company_share_reward_pct,
      'duration_months', coalesce(v_referred.referral_duration_months, 12), 'effective_from', v_setting.effective_from,
      'funding_source', 'mfa_company_share_only', 'agent_share_pct_unchanged', true,
      'operations_risk_reserve_unchanged', true),
    false
  ) on conflict (commission_entry_id) do nothing;
  return new;
end;
$$;
revoke all on function private.mfa_create_referral_commission_entry() from public, anon, authenticated;
create trigger mfa_commission_referral_calculation
after insert on public.mfa_commission_entries
for each row execute function private.mfa_create_referral_commission_entry();

create trigger mfa_referral_commission_entries_immutable
before update or delete on public.mfa_referral_commission_entries
for each row execute function private.mfa_reject_immutable_mutation();

create index if not exists mfa_referral_entries_referrer_date_idx
  on public.mfa_referral_commission_entries(referrer_agent_id, calculated_at desc);
create index if not exists mfa_referral_entries_referred_date_idx
  on public.mfa_referral_commission_entries(referred_agent_id, calculated_at desc);

comment on table public.mfa_referral_commission_entries is
'Direct-agent referral calculations funded only from MFA company commission share; immutable and non-payable in V1.';
