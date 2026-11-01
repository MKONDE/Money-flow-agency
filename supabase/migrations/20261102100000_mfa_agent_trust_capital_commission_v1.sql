-- MFA Agent Trust, Capital & Commission Engine V1
-- Additive migration. Apply ONLY to the dedicated money-flow-agency Supabase project.
-- No wallet, custody, escrow balance, deposit, withdrawal, transfer or payment execution is created.

create schema if not exists private;

-- 1. Trust classification and immutable history.
create table if not exists public.mfa_agent_trust_badges (
  agent_id uuid primary key references public.agent_profiles(id) on delete cascade,
  trust_level text not null default 'independent_agent'
    check (trust_level in ('independent_agent','verified_agent','capital_backed_agent','premium_agent','strategic_agent')),
  badge_status text not null default 'active' check (badge_status in ('active','suspended','revoked')),
  reason text,
  assigned_by uuid references auth.users(id),
  assigned_at timestamptz not null default now(),
  valid_until timestamptz,
  updated_at timestamptz not null default now(),
  check (valid_until is null or valid_until > assigned_at)
);
create table if not exists public.mfa_agent_trust_history (
  id bigint generated always as identity primary key,
  agent_id uuid not null references public.agent_profiles(id) on delete cascade,
  previous_level text,
  new_level text not null,
  badge_status text not null,
  reason text,
  actor_id uuid references auth.users(id),
  created_at timestamptz not null default now()
);

-- 2. Declared capital, separately declared float, verified guarantee references and configurable tiers.
create table if not exists public.mfa_capital_tiers (
  id uuid primary key default gen_random_uuid(),
  tier_code text not null,
  tier_name text not null,
  currency char(3) not null,
  minimum_declared_capital numeric(20,2) not null default 0 check (minimum_declared_capital >= 0),
  minimum_verified_guarantee numeric(20,2) not null default 0 check (minimum_verified_guarantee >= 0),
  max_per_transaction numeric(20,2) not null check (max_per_transaction > 0),
  max_pending_exposure numeric(20,2) not null check (max_pending_exposure > 0),
  max_daily_volume numeric(20,2) not null check (max_daily_volume > 0),
  max_monthly_volume numeric(20,2) not null check (max_monthly_volume > 0),
  enabled boolean not null default true,
  effective_from timestamptz not null default now(),
  effective_to timestamptz,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (effective_to is null or effective_to > effective_from),
  unique(tier_code,currency,effective_from)
);
create table if not exists public.mfa_agent_capital_profiles (
  agent_id uuid primary key references public.agent_profiles(id) on delete cascade,
  currency char(3) not null,
  declared_capital numeric(20,2) not null check (declared_capital >= 0),
  declared_transaction_float numeric(20,2) not null default 0 check (declared_transaction_float >= 0),
  declaration_notes text,
  submitted_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.mfa_agent_guarantees (
  id uuid primary key default gen_random_uuid(),
  agent_id uuid not null references public.agent_profiles(id) on delete cascade,
  guarantee_type text not null check (guarantee_type in ('bank_guarantee_reference','insurance_bond_reference','licensed_provider_reference','other_documentary_reference')),
  issuer_name text not null,
  guarantee_reference text not null,
  amount numeric(20,2) not null check (amount > 0),
  currency char(3) not null,
  valid_from date,
  valid_until date,
  evidence_reference text,
  verification_status text not null default 'pending' check (verification_status in ('pending','verified','rejected','expired')),
  verification_reason text,
  verified_by uuid references auth.users(id),
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (valid_until is null or valid_from is null or valid_until >= valid_from),
  unique(agent_id,guarantee_reference)
);

-- 3. Tracked transactions only. simulation_only is hard-constrained to TRUE.
create table if not exists public.mfa_transactions (
  id uuid primary key default gen_random_uuid(),
  reference_code text not null unique default ('MFA-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,16))),
  requester_id uuid not null references auth.users(id),
  agent_id uuid references public.agent_profiles(id),
  partner_id uuid references public.business_partners(id),
  service_code text not null default 'general',
  customer_reference text,
  agent_reference text,
  partner_reference text,
  country_code char(2) not null,
  currency char(3) not null,
  payment_network text,
  amount numeric(20,2) not null check (amount > 0),
  commissionable_amount numeric(20,2) not null default 0 check (commissionable_amount >= 0 and commissionable_amount <= amount),
  status text not null default 'CREATED'
    check (status in ('CREATED','PENDING_AGENT','PAYMENT_PENDING','PAYMENT_SUBMITTED','UNDER_REVIEW','CONFIRMED','COMPLETED','REJECTED','DISPUTED','CANCELLED','EXPIRED')),
  customer_note text,
  evidence_reference text,
  simulation_only boolean not null default true check (simulation_only = true),
  commission_calculated boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.mfa_transaction_status_history (
  id bigint generated always as identity primary key,
  transaction_id uuid not null references public.mfa_transactions(id) on delete restrict,
  previous_status text,
  new_status text not null,
  actor_id uuid references auth.users(id),
  actor_role text,
  note text,
  created_at timestamptz not null default now()
);

-- 4. Disputes and append-only dispute events.
create table if not exists public.mfa_transaction_disputes (
  id uuid primary key default gen_random_uuid(),
  transaction_id uuid not null references public.mfa_transactions(id) on delete restrict,
  opened_by uuid not null references auth.users(id),
  reason_code text not null,
  description text not null,
  dispute_status text not null default 'open' check (dispute_status in ('open','under_review','resolved','rejected')),
  resolution_note text,
  resolved_by uuid references auth.users(id),
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.mfa_dispute_events (
  id bigint generated always as identity primary key,
  dispute_id uuid not null references public.mfa_transaction_disputes(id) on delete restrict,
  actor_id uuid references auth.users(id),
  event_type text not null,
  note text,
  created_at timestamptz not null default now()
);

-- 5. Escrow-ready metadata only. There is deliberately no amount, balance, custody or release API.
create table if not exists public.mfa_escrow_workflows (
  id uuid primary key default gen_random_uuid(),
  transaction_id uuid not null unique references public.mfa_transactions(id) on delete restrict,
  workflow_status text not null default 'prepared' check (workflow_status in ('prepared','awaiting_customer_confirmation','disputed','closed')),
  future_licensed_provider_code text,
  release_conditions text not null,
  customer_confirmation_required boolean not null default true,
  customer_confirmed_at timestamptz,
  dispute_status text not null default 'none' check (dispute_status in ('none','open','under_review','resolved')),
  funds_held boolean not null default false check (funds_held = false),
  release_executed boolean not null default false check (release_executed = false),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 6. Commission configuration and immutable, non-payable calculation records.
create table if not exists public.mfa_commission_rules (
  id uuid primary key default gen_random_uuid(),
  rule_name text not null,
  scope_type text not null check (scope_type in ('global','country','service','agent','partner')),
  scope_key text not null,
  currency char(3),
  agent_share_pct numeric(7,4) not null default 70 check (agent_share_pct >= 0 and agent_share_pct <= 100),
  company_share_pct numeric(7,4) not null default 20 check (company_share_pct >= 0 and company_share_pct <= 100),
  operations_reserve_pct numeric(7,4) not null default 10 check (operations_reserve_pct >= 0 and operations_reserve_pct <= 100),
  minimum_commission_pool numeric(20,2) not null default 0 check (minimum_commission_pool >= 0),
  maximum_commission_pool numeric(20,2),
  effective_from timestamptz not null default now(),
  effective_to timestamptz,
  enabled boolean not null default true,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (round(agent_share_pct + company_share_pct + operations_reserve_pct,4) = 100),
  check (maximum_commission_pool is null or maximum_commission_pool >= minimum_commission_pool),
  check (effective_to is null or effective_to > effective_from),
  check ((scope_type='global' and scope_key='*') or (scope_type<>'global' and length(trim(scope_key))>0))
);
create unique index if not exists mfa_commission_rules_scope_effective_idx
  on public.mfa_commission_rules(scope_type,scope_key,coalesce(currency,'*'),effective_from);
create table if not exists public.mfa_commission_entries (
  id uuid primary key default gen_random_uuid(),
  transaction_id uuid not null unique references public.mfa_transactions(id) on delete restrict,
  agent_id uuid not null references public.agent_profiles(id) on delete restrict,
  partner_id uuid references public.business_partners(id),
  country_code char(2) not null,
  service_code text not null,
  currency char(3) not null,
  commission_pool numeric(20,2) not null check (commission_pool >= 0),
  agent_commission numeric(20,2) not null check (agent_commission >= 0),
  company_revenue numeric(20,2) not null check (company_revenue >= 0),
  operations_risk_reserve numeric(20,2) not null check (operations_risk_reserve >= 0),
  rounding_remainder numeric(20,2) not null default 0,
  rule_id uuid references public.mfa_commission_rules(id),
  rule_snapshot jsonb not null,
  calculated_at timestamptz not null default now(),
  payable boolean not null default false check (payable = false)
);

create table if not exists public.mfa_financial_audit_events (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users(id),
  table_name text not null,
  record_id text,
  operation text not null check (operation in ('INSERT','UPDATE','DELETE')),
  before_data jsonb,
  after_data jsonb,
  created_at timestamptz not null default now()
);

-- Seed the requested default split. This is a calculation allocation only, not a promise of payment.
insert into public.mfa_commission_rules(rule_name,scope_type,scope_key,agent_share_pct,company_share_pct,operations_reserve_pct)
select 'MFA Global Default 70/20/10','global','*',70,20,10
where not exists(select 1 from public.mfa_commission_rules where scope_type='global' and scope_key='*' and currency is null and enabled=true);

-- Agent trust badges default to Independent Agent; only an AAL2 Super Admin can elevate them.
insert into public.mfa_agent_trust_badges(agent_id,trust_level,badge_status)
select id,'independent_agent','active' from public.agent_profiles
on conflict(agent_id) do nothing;

-- RLS on every new table in the exposed public schema.
alter table public.mfa_agent_trust_badges enable row level security;
alter table public.mfa_agent_trust_history enable row level security;
alter table public.mfa_capital_tiers enable row level security;
alter table public.mfa_agent_capital_profiles enable row level security;
alter table public.mfa_agent_guarantees enable row level security;
alter table public.mfa_transactions enable row level security;
alter table public.mfa_transaction_status_history enable row level security;
alter table public.mfa_transaction_disputes enable row level security;
alter table public.mfa_dispute_events enable row level security;
alter table public.mfa_escrow_workflows enable row level security;
alter table public.mfa_commission_rules enable row level security;
alter table public.mfa_commission_entries enable row level security;
alter table public.mfa_financial_audit_events enable row level security;

-- Trust badges: only active, non-expired badges on verified agent profiles are public.
create policy mfa_trust_public_read on public.mfa_agent_trust_badges for select to anon,authenticated
using (badge_status='active' and (valid_until is null or valid_until>now())
  and exists(select 1 from public.agent_profiles a where a.id=agent_id and a.status='verified'));
create policy mfa_trust_admin_all on public.mfa_agent_trust_badges for all to authenticated
using ((select private.current_mfa_role())='super_admin' and (select auth.jwt()->>'aal')='aal2')
with check ((select private.current_mfa_role())='super_admin' and (select auth.jwt()->>'aal')='aal2');
create policy mfa_trust_history_admin_read on public.mfa_agent_trust_history for select to authenticated
using ((select private.current_mfa_role())='super_admin' and (select auth.jwt()->>'aal')='aal2');

-- Capital declarations: agent owns declaration fields; admins can review all.
create policy mfa_capital_owner_read on public.mfa_agent_capital_profiles for select to authenticated
using (exists(select 1 from public.agent_profiles a where a.id=agent_id and a.user_id=(select auth.uid())));
create policy mfa_capital_owner_insert on public.mfa_agent_capital_profiles for insert to authenticated
with check (exists(select 1 from public.agent_profiles a where a.id=agent_id and a.user_id=(select auth.uid())));
create policy mfa_capital_owner_update on public.mfa_agent_capital_profiles for update to authenticated
using (exists(select 1 from public.agent_profiles a where a.id=agent_id and a.user_id=(select auth.uid())))
with check (exists(select 1 from public.agent_profiles a where a.id=agent_id and a.user_id=(select auth.uid())));
create policy mfa_capital_admin_all on public.mfa_agent_capital_profiles for all to authenticated
using ((select private.current_mfa_role())='super_admin' and (select auth.jwt()->>'aal')='aal2')
with check ((select private.current_mfa_role())='super_admin' and (select auth.jwt()->>'aal')='aal2');

create policy mfa_guarantee_owner_read on public.mfa_agent_guarantees for select to authenticated
using (exists(select 1 from public.agent_profiles a where a.id=agent_id and a.user_id=(select auth.uid())));
create policy mfa_guarantee_owner_insert on public.mfa_agent_guarantees for insert to authenticated
with check (verification_status='pending' and verified_by is null and verified_at is null
  and exists(select 1 from public.agent_profiles a where a.id=agent_id and a.user_id=(select auth.uid())));
create policy mfa_guarantee_admin_all on public.mfa_agent_guarantees for all to authenticated
using ((select private.current_mfa_role())='super_admin' and (select auth.jwt()->>'aal')='aal2')
with check ((select private.current_mfa_role())='super_admin' and (select auth.jwt()->>'aal')='aal2');

-- Capital tiers are visible to signed-in users, but only admins can configure them.
create policy mfa_tiers_authenticated_read on public.mfa_capital_tiers for select to authenticated using (enabled=true);
create policy mfa_tiers_admin_all on public.mfa_capital_tiers for all to authenticated
using ((select private.current_mfa_role())='super_admin' and (select auth.jwt()->>'aal')='aal2')
with check ((select private.current_mfa_role())='super_admin' and (select auth.jwt()->>'aal')='aal2');

-- Transaction ownership and assigned-agent visibility. All customer-created records are simulation-only.
create policy mfa_transactions_customer_read on public.mfa_transactions for select to authenticated
using (requester_id=(select auth.uid()));
create policy mfa_transactions_agent_read on public.mfa_transactions for select to authenticated
using (exists(select 1 from public.agent_profiles a where a.id=agent_id and a.user_id=(select auth.uid())));
create policy mfa_transactions_customer_insert on public.mfa_transactions for insert to authenticated
with check (requester_id=(select auth.uid()) and agent_id is null and status='CREATED' and simulation_only=true and commissionable_amount=0);
create policy mfa_transactions_agent_update on public.mfa_transactions for update to authenticated
using (exists(select 1 from public.agent_profiles a where a.id=agent_id and a.user_id=(select auth.uid())))
with check (exists(select 1 from public.agent_profiles a where a.id=agent_id and a.user_id=(select auth.uid())));
create policy mfa_transactions_admin_all on public.mfa_transactions for all to authenticated
using ((select private.current_mfa_role())='super_admin' and (select auth.jwt()->>'aal')='aal2')
with check ((select private.current_mfa_role())='super_admin' and (select auth.jwt()->>'aal')='aal2');

create policy mfa_transaction_history_owner_read on public.mfa_transaction_status_history for select to authenticated
using (exists(select 1 from public.mfa_transactions t where t.id=transaction_id and
  (t.requester_id=(select auth.uid()) or exists(select 1 from public.agent_profiles a where a.id=t.agent_id and a.user_id=(select auth.uid())))));
create policy mfa_transaction_history_admin_read on public.mfa_transaction_status_history for select to authenticated
using ((select private.current_mfa_role())='super_admin' and (select auth.jwt()->>'aal')='aal2');

create policy mfa_disputes_owner_read on public.mfa_transaction_disputes for select to authenticated
using (opened_by=(select auth.uid()) or exists(select 1 from public.mfa_transactions t where t.id=transaction_id and
  (t.requester_id=(select auth.uid()) or exists(select 1 from public.agent_profiles a where a.id=t.agent_id and a.user_id=(select auth.uid())))));
create policy mfa_disputes_owner_insert on public.mfa_transaction_disputes for insert to authenticated
with check (opened_by=(select auth.uid()) and exists(select 1 from public.mfa_transactions t where t.id=transaction_id and
  (t.requester_id=(select auth.uid()) or exists(select 1 from public.agent_profiles a where a.id=t.agent_id and a.user_id=(select auth.uid())))));
create policy mfa_disputes_admin_all on public.mfa_transaction_disputes for all to authenticated
using ((select private.current_mfa_role())='super_admin' and (select auth.jwt()->>'aal')='aal2')
with check ((select private.current_mfa_role())='super_admin' and (select auth.jwt()->>'aal')='aal2');
create policy mfa_dispute_events_owner_read on public.mfa_dispute_events for select to authenticated
using (exists(select 1 from public.mfa_transaction_disputes d join public.mfa_transactions t on t.id=d.transaction_id
  where d.id=dispute_id and (d.opened_by=(select auth.uid()) or t.requester_id=(select auth.uid())
  or exists(select 1 from public.agent_profiles a where a.id=t.agent_id and a.user_id=(select auth.uid())))));
create policy mfa_dispute_events_admin_read on public.mfa_dispute_events for select to authenticated
using ((select private.current_mfa_role())='super_admin' and (select auth.jwt()->>'aal')='aal2');

create policy mfa_escrow_owner_read on public.mfa_escrow_workflows for select to authenticated
using (exists(select 1 from public.mfa_transactions t where t.id=transaction_id and
  (t.requester_id=(select auth.uid()) or exists(select 1 from public.agent_profiles a where a.id=t.agent_id and a.user_id=(select auth.uid())))));
create policy mfa_escrow_admin_all on public.mfa_escrow_workflows for all to authenticated
using ((select private.current_mfa_role())='super_admin' and (select auth.jwt()->>'aal')='aal2')
with check ((select private.current_mfa_role())='super_admin' and (select auth.jwt()->>'aal')='aal2');
create policy mfa_escrow_customer_confirm on public.mfa_escrow_workflows for update to authenticated
using (customer_confirmation_required=true and customer_confirmed_at is null and workflow_status='awaiting_customer_confirmation'
  and exists(select 1 from public.mfa_transactions t where t.id=transaction_id and t.requester_id=(select auth.uid())))
with check (customer_confirmed_at is not null and exists(select 1 from public.mfa_transactions t where t.id=transaction_id and t.requester_id=(select auth.uid())));

create policy mfa_commission_rules_admin_read on public.mfa_commission_rules for select to authenticated
using ((select private.current_mfa_role())='super_admin' and (select auth.jwt()->>'aal')='aal2');
create policy mfa_commission_rules_admin_write on public.mfa_commission_rules for all to authenticated
using ((select private.current_mfa_role())='super_admin' and (select auth.jwt()->>'aal')='aal2')
with check ((select private.current_mfa_role())='super_admin' and (select auth.jwt()->>'aal')='aal2');
create policy mfa_commission_entries_agent_read on public.mfa_commission_entries for select to authenticated
using (exists(select 1 from public.agent_profiles a where a.id=agent_id and a.user_id=(select auth.uid())));
create policy mfa_commission_entries_admin_read on public.mfa_commission_entries for select to authenticated
using ((select private.current_mfa_role())='super_admin' and (select auth.jwt()->>'aal')='aal2');
create policy mfa_financial_audit_admin_read on public.mfa_financial_audit_events for select to authenticated
using ((select private.current_mfa_role())='super_admin' and (select auth.jwt()->>'aal')='aal2');

-- Narrow table privileges. No customer/agent can write status history, commission entries, audit rows or escrow actions.
revoke all on public.mfa_agent_trust_badges,public.mfa_agent_trust_history,public.mfa_capital_tiers,
  public.mfa_agent_capital_profiles,public.mfa_agent_guarantees,public.mfa_transactions,
  public.mfa_transaction_status_history,public.mfa_transaction_disputes,public.mfa_dispute_events,
  public.mfa_escrow_workflows,public.mfa_commission_rules,public.mfa_commission_entries,
  public.mfa_financial_audit_events from anon,authenticated;

grant select on public.mfa_agent_trust_badges to anon,authenticated;
grant insert,update on public.mfa_agent_trust_badges to authenticated;
grant select on public.mfa_agent_trust_history to authenticated;
grant select on public.mfa_capital_tiers to authenticated;
grant select,insert,update on public.mfa_agent_capital_profiles to authenticated;
grant select,insert on public.mfa_agent_guarantees to authenticated;
grant update on public.mfa_agent_guarantees to authenticated;
grant select,insert,update on public.mfa_transactions to authenticated;
grant select on public.mfa_transaction_status_history,public.mfa_dispute_events,public.mfa_escrow_workflows to authenticated;
grant select,insert,update on public.mfa_transaction_disputes to authenticated;
grant select,insert,update on public.mfa_capital_tiers,public.mfa_commission_rules,public.mfa_escrow_workflows to authenticated;
grant select on public.mfa_commission_entries,public.mfa_financial_audit_events to authenticated;

-- Restrict agents to declaration fields and status/evidence updates; trigger checks each transition and assignment.
revoke update on public.mfa_agent_capital_profiles from authenticated;
grant update(currency,declared_capital,declared_transaction_float,declaration_notes) on public.mfa_agent_capital_profiles to authenticated;
revoke update on public.mfa_transactions from authenticated;
grant update(agent_id,partner_id,service_code,country_code,currency,payment_network,amount,commissionable_amount,customer_reference,agent_reference,partner_reference,status,evidence_reference,customer_note) on public.mfa_transactions to authenticated;
revoke insert on public.mfa_transactions from authenticated;
grant insert(requester_id,partner_id,service_code,country_code,currency,payment_network,amount,customer_reference,customer_note,simulation_only) on public.mfa_transactions to authenticated;
revoke update on public.mfa_transaction_disputes from authenticated;
grant update(dispute_status,resolution_note,resolved_by,resolved_at) on public.mfa_transaction_disputes to authenticated;
revoke update on public.mfa_agent_guarantees from authenticated;
grant update on public.mfa_agent_guarantees to authenticated;

-- Trigger helpers are private and cannot be invoked as public RPC endpoints.
create or replace function private.mfa_touch_updated_at()
returns trigger language plpgsql set search_path='' as $$
begin new.updated_at=now(); return new; end; $$;
revoke all on function private.mfa_touch_updated_at() from public,anon,authenticated;

create or replace function private.mfa_seed_agent_trust_badge()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  insert into public.mfa_agent_trust_badges(agent_id,trust_level,badge_status)
  values(new.id,'independent_agent','active') on conflict(agent_id) do nothing;
  return new;
end; $$;
revoke all on function private.mfa_seed_agent_trust_badge() from public,anon,authenticated;
drop trigger if exists mfa_seed_agent_trust_badge on public.agent_profiles;
create trigger mfa_seed_agent_trust_badge after insert on public.agent_profiles
for each row execute function private.mfa_seed_agent_trust_badge();

create or replace function private.mfa_guard_trust_badge_change()
returns trigger language plpgsql security definer set search_path='' as $
declare v_agent_status text; v_declared numeric(20,2); v_verified_guarantee numeric(20,2);
begin
  select status into v_agent_status from public.agent_profiles where id=new.agent_id;
  if new.trust_level<>'independent_agent' and v_agent_status is distinct from 'verified' then
    raise exception 'Trust levels above Independent Agent require a verified agent profile' using errcode='42501';
  end if;
  if new.trust_level='capital_backed_agent' then
    select declared_capital into v_declared from public.mfa_agent_capital_profiles where agent_id=new.agent_id;
    select coalesce(sum(amount),0) into v_verified_guarantee from public.mfa_agent_guarantees
      where agent_id=new.agent_id and verification_status='verified' and (valid_until is null or valid_until>=current_date);
    if coalesce(v_declared,0)<=0 or v_verified_guarantee<=0 then
      raise exception 'Capital-Backed Agent requires declared capital and a separately verified guarantee' using errcode='23514';
    end if;
  end if;
  if tg_op='UPDATE' and (old.trust_level is distinct from new.trust_level or old.badge_status is distinct from new.badge_status) then
    insert into public.mfa_agent_trust_history(agent_id,previous_level,new_level,badge_status,reason,actor_id)
    values(new.agent_id,old.trust_level,new.trust_level,new.badge_status,new.reason,auth.uid());
  end if;
  return new;
end; $$;
revoke all on function private.mfa_guard_trust_badge_change() from public,anon,authenticated;
create trigger mfa_trust_badge_guard before insert or update on public.mfa_agent_trust_badges
for each row execute function private.mfa_guard_trust_badge_change();

create or replace function private.mfa_enforce_agent_transaction_limits()
returns trigger language plpgsql security definer set search_path='' as $$
declare
  v_agent_status text;
  v_capital public.mfa_agent_capital_profiles%rowtype;
  v_guarantee numeric(20,2);
  v_tier public.mfa_capital_tiers%rowtype;
  v_pending numeric(20,2);
  v_daily numeric(20,2);
  v_monthly numeric(20,2);
begin
  if new.agent_id is null then return new; end if;
  select status into v_agent_status from public.agent_profiles where id=new.agent_id;
  if v_agent_status is distinct from 'verified' then
    raise exception 'Only verified agents can be assigned tracked transactions' using errcode='42501';
  end if;
  select * into v_capital from public.mfa_agent_capital_profiles where agent_id=new.agent_id;
  if not found or v_capital.currency<>new.currency then
    raise exception 'Agent capital declaration is missing or currency does not match' using errcode='23514';
  end if;
  select coalesce(sum(amount),0) into v_guarantee from public.mfa_agent_guarantees
   where agent_id=new.agent_id and currency=new.currency and verification_status='verified'
   and (valid_from is null or valid_from<=current_date) and (valid_until is null or valid_until>=current_date);
  select * into v_tier from public.mfa_capital_tiers
   where enabled=true and currency=new.currency and effective_from<=now() and (effective_to is null or effective_to>now())
   and minimum_declared_capital<=v_capital.declared_capital and minimum_verified_guarantee<=v_guarantee
   order by minimum_verified_guarantee desc,minimum_declared_capital desc,effective_from desc limit 1;
  if not found then raise exception 'No active capital tier matches this agent declaration and verified guarantee' using errcode='23514'; end if;
  if new.amount>v_tier.max_per_transaction then raise exception 'Transaction exceeds agent per-transaction limit' using errcode='23514'; end if;

  select coalesce(sum(t.amount),0) into v_pending from public.mfa_transactions t
   where t.agent_id=new.agent_id and t.currency=new.currency and t.status in ('PENDING_AGENT','PAYMENT_PENDING','PAYMENT_SUBMITTED','UNDER_REVIEW','CONFIRMED','DISPUTED')
   and (new.id is null or t.id<>new.id);
  if v_pending+new.amount>v_tier.max_pending_exposure then raise exception 'Agent pending exposure limit exceeded' using errcode='23514'; end if;

  select coalesce(sum(t.amount),0) into v_daily from public.mfa_transactions t
   where t.agent_id=new.agent_id and t.currency=new.currency and t.created_at>=date_trunc('day',now())
   and t.status not in ('REJECTED','CANCELLED','EXPIRED') and (new.id is null or t.id<>new.id);
  if v_daily+new.amount>v_tier.max_daily_volume then raise exception 'Agent daily volume limit exceeded' using errcode='23514'; end if;

  select coalesce(sum(t.amount),0) into v_monthly from public.mfa_transactions t
   where t.agent_id=new.agent_id and t.currency=new.currency and t.created_at>=date_trunc('month',now())
   and t.status not in ('REJECTED','CANCELLED','EXPIRED') and (new.id is null or t.id<>new.id);
  if v_monthly+new.amount>v_tier.max_monthly_volume then raise exception 'Agent monthly volume limit exceeded' using errcode='23514'; end if;
  return new;
end; $$;
revoke all on function private.mfa_enforce_agent_transaction_limits() from public,anon,authenticated;
create trigger mfa_agent_transaction_limits before insert or update of agent_id,amount,currency
on public.mfa_transactions for each row execute function private.mfa_enforce_agent_transaction_limits();

create or replace function private.mfa_validate_transaction_transition()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_role text:=private.current_mfa_role(); v_agent_user uuid;
begin
  if tg_op='INSERT' then
    if new.status<>'CREATED' or new.simulation_only is not true or new.commissionable_amount<>0 then
      raise exception 'Customer transaction submissions must begin as simulation-only CREATED records' using errcode='42501';
    end if;
    return new;
  end if;
  if new.agent_id is distinct from old.agent_id and not (v_role='super_admin' and (select auth.jwt()->>'aal')='aal2') then
    raise exception 'Only an AAL2 Super Admin may assign or reassign an agent' using errcode='42501';
  end if;
  if new.commissionable_amount is distinct from old.commissionable_amount
    or new.service_code is distinct from old.service_code
    or new.payment_network is distinct from old.payment_network
    or new.customer_reference is distinct from old.customer_reference
    or new.agent_reference is distinct from old.agent_reference
    or new.partner_reference is distinct from old.partner_reference
    or new.customer_note is distinct from old.customer_note
    or new.partner_id is distinct from old.partner_id
    or new.amount is distinct from old.amount
    or new.currency is distinct from old.currency
    or new.country_code is distinct from old.country_code
    or new.requester_id is distinct from old.requester_id
    or new.simulation_only is distinct from old.simulation_only then
    if not (v_role='super_admin' and (select auth.jwt()->>'aal')='aal2') then
      raise exception 'Only an AAL2 Super Admin may edit financial tracking metadata' using errcode='42501';
    end if;
  end if;
  if new.status is distinct from old.status then
    if v_role='super_admin' and (select auth.jwt()->>'aal')='aal2' then
      if not ((old.status='CREATED' and new.status in ('PENDING_AGENT','CANCELLED','EXPIRED'))
        or (old.status='PENDING_AGENT' and new.status in ('PAYMENT_PENDING','REJECTED','CANCELLED','EXPIRED'))
        or (old.status='PAYMENT_PENDING' and new.status in ('PAYMENT_SUBMITTED','CANCELLED','EXPIRED'))
        or (old.status='PAYMENT_SUBMITTED' and new.status in ('UNDER_REVIEW','DISPUTED','REJECTED'))
        or (old.status='UNDER_REVIEW' and new.status in ('CONFIRMED','REJECTED','DISPUTED'))
        or (old.status='CONFIRMED' and new.status in ('COMPLETED','DISPUTED'))
        or (old.status='COMPLETED' and new.status='DISPUTED')
        or (old.status='DISPUTED' and new.status in ('CONFIRMED','REJECTED','CANCELLED'))) then
        raise exception 'Invalid transaction status transition' using errcode='22023';
      end if;
    else
      select user_id into v_agent_user from public.agent_profiles where id=old.agent_id;
      if new.status='DISPUTED' and exists(select 1 from public.mfa_transaction_disputes d where d.transaction_id=old.id and d.opened_by=auth.uid() and d.dispute_status='open') then
        null;
      elsif v_agent_user is distinct from auth.uid() or not (
        (old.status='PENDING_AGENT' and new.status='PAYMENT_PENDING')
        or (old.status='PAYMENT_PENDING' and new.status='PAYMENT_SUBMITTED')
      ) then
        raise exception 'Agent may only advance an assigned request to PAYMENT_PENDING or PAYMENT_SUBMITTED' using errcode='42501';
      end if;
    end if;
  end if;
  return new;
end; $$;
revoke all on function private.mfa_validate_transaction_transition() from public,anon,authenticated;
create trigger mfa_transaction_transition_guard before insert or update on public.mfa_transactions
for each row execute function private.mfa_validate_transaction_transition();

create or replace function private.mfa_record_transaction_status()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if tg_op='INSERT' then
    insert into public.mfa_transaction_status_history(transaction_id,previous_status,new_status,actor_id,actor_role,note)
    values(new.id,null,new.status,auth.uid(),coalesce(private.current_mfa_role(),'customer'),'Tracking-only transaction created');
  elsif new.status is distinct from old.status then
    insert into public.mfa_transaction_status_history(transaction_id,previous_status,new_status,actor_id,actor_role,note)
    values(new.id,old.status,new.status,auth.uid(),coalesce(private.current_mfa_role(),'customer'),null);
  end if;
  return new;
end; $$;
revoke all on function private.mfa_record_transaction_status() from public,anon,authenticated;
create trigger mfa_transaction_status_history_trigger after insert or update of status
on public.mfa_transactions for each row execute function private.mfa_record_transaction_status();

create or replace function private.mfa_create_commission_entry()
returns trigger language plpgsql security definer set search_path='' as $$
declare
  v_rule public.mfa_commission_rules%rowtype;
  v_pool numeric(20,2);
  v_agent numeric(20,2);
  v_company numeric(20,2);
  v_reserve numeric(20,2);
  v_remainder numeric(20,2);
  v_agent_status text;
begin
  if new.status<>'COMPLETED' or old.status='COMPLETED' or new.agent_id is null or new.commissionable_amount<=0 then return new; end if;
  select status into v_agent_status from public.agent_profiles where id=new.agent_id;
  if v_agent_status is distinct from 'verified' then return new; end if;
  select * into v_rule from public.mfa_commission_rules r
   where r.enabled=true and r.effective_from<=now() and (r.effective_to is null or r.effective_to>now())
   and (r.currency is null or r.currency=new.currency)
   and ((r.scope_type='agent' and r.scope_key=new.agent_id::text)
     or (r.scope_type='partner' and r.scope_key=coalesce(new.partner_id::text,''))
     or (r.scope_type='service' and r.scope_key=new.service_code)
     or (r.scope_type='country' and r.scope_key=new.country_code::text)
     or (r.scope_type='global' and r.scope_key='*'))
   order by case r.scope_type when 'agent' then 1 when 'partner' then 2 when 'service' then 3 when 'country' then 4 else 5 end,
     (r.currency is not null) desc,r.effective_from desc limit 1;
  if not found then return new; end if;
  if new.commissionable_amount<v_rule.minimum_commission_pool then return new; end if;
  v_pool:=case when v_rule.maximum_commission_pool is null then new.commissionable_amount
    else least(new.commissionable_amount,v_rule.maximum_commission_pool) end;
  v_agent:=round(v_pool*v_rule.agent_share_pct/100,2);
  v_company:=round(v_pool*v_rule.company_share_pct/100,2);
  v_reserve:=round(v_pool*v_rule.operations_reserve_pct/100,2);
  v_remainder:=v_pool-v_agent-v_company-v_reserve;
  insert into public.mfa_commission_entries(transaction_id,agent_id,partner_id,country_code,service_code,currency,
    commission_pool,agent_commission,company_revenue,operations_risk_reserve,rounding_remainder,rule_id,rule_snapshot,payable)
  values(new.id,new.agent_id,new.partner_id,new.country_code,new.service_code,new.currency,v_pool,v_agent,v_company,v_reserve,v_remainder,v_rule.id,
    jsonb_build_object('rule_name',v_rule.rule_name,'scope_type',v_rule.scope_type,'scope_key',v_rule.scope_key,
      'currency',v_rule.currency,'agent_share_pct',v_rule.agent_share_pct,'company_share_pct',v_rule.company_share_pct,
      'operations_reserve_pct',v_rule.operations_reserve_pct,'minimum_commission_pool',v_rule.minimum_commission_pool,
      'maximum_commission_pool',v_rule.maximum_commission_pool,'effective_from',v_rule.effective_from,'effective_to',v_rule.effective_to),
    false) on conflict(transaction_id) do nothing;
  update public.mfa_transactions set commission_calculated=true where id=new.id;
  return new;
end; $$;
revoke all on function private.mfa_create_commission_entry() from public,anon,authenticated;
create trigger mfa_transaction_commission_calculation after update of status
on public.mfa_transactions for each row execute function private.mfa_create_commission_entry();

create or replace function private.mfa_open_dispute_on_insert()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  update public.mfa_transactions set status='DISPUTED' where id=new.transaction_id
    and status in ('PAYMENT_SUBMITTED','UNDER_REVIEW','CONFIRMED','COMPLETED');
  insert into public.mfa_dispute_events(dispute_id,actor_id,event_type,note)
  values(new.id,new.opened_by,'dispute_opened',new.reason_code);
  return new;
end; $$;
revoke all on function private.mfa_open_dispute_on_insert() from public,anon,authenticated;
create trigger mfa_dispute_opened after insert on public.mfa_transaction_disputes
for each row execute function private.mfa_open_dispute_on_insert();

create or replace function private.mfa_record_dispute_update()
returns trigger language plpgsql security definer set search_path='' as $
begin
  if new.dispute_status is distinct from old.dispute_status or new.resolution_note is distinct from old.resolution_note then
    insert into public.mfa_dispute_events(dispute_id,actor_id,event_type,note)
    values(new.id,auth.uid(),'dispute_'||new.dispute_status,new.resolution_note);
  end if;
  return new;
end; $;
revoke all on function private.mfa_record_dispute_update() from public,anon,authenticated;
create trigger mfa_dispute_update_event after update on public.mfa_transaction_disputes
for each row execute function private.mfa_record_dispute_update();

create or replace function private.mfa_guard_escrow_update()
returns trigger language plpgsql security definer set search_path='' as $
declare v_admin boolean := private.current_mfa_role()='super_admin' and (select auth.jwt()->>'aal')='aal2';
begin
  if not v_admin then
    if new.id is distinct from old.id or new.transaction_id is distinct from old.transaction_id
      or new.workflow_status is distinct from old.workflow_status
      or new.future_licensed_provider_code is distinct from old.future_licensed_provider_code
      or new.release_conditions is distinct from old.release_conditions
      or new.customer_confirmation_required is distinct from old.customer_confirmation_required
      or new.dispute_status is distinct from old.dispute_status
      or new.funds_held is distinct from old.funds_held
      or new.release_executed is distinct from old.release_executed
      or new.created_by is distinct from old.created_by then
      raise exception 'Customer confirmation cannot change escrow workflow controls' using errcode='42501';
    end if;
    if not exists(select 1 from public.mfa_transactions t where t.id=old.transaction_id and t.requester_id=auth.uid())
      or old.customer_confirmed_at is not null or new.customer_confirmed_at is null then
      raise exception 'Only the transaction customer may confirm once' using errcode='42501';
    end if;
    new.workflow_status:='closed';
  end if;
  if new.funds_held is true or new.release_executed is true then
    raise exception 'MFA V1 cannot hold funds or execute escrow releases' using errcode='42501';
  end if;
  return new;
end; $;
revoke all on function private.mfa_guard_escrow_update() from public,anon,authenticated;
create trigger mfa_escrow_update_guard before update on public.mfa_escrow_workflows
for each row execute function private.mfa_guard_escrow_update();

create or replace function private.mfa_audit_row_change()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_id text; v_before jsonb; v_after jsonb;
begin
  if tg_op='DELETE' then v_id:=coalesce(to_jsonb(old)->>'id',to_jsonb(old)->>'agent_id'); v_before:=to_jsonb(old);
  elsif tg_op='UPDATE' then v_id:=coalesce(to_jsonb(new)->>'id',to_jsonb(new)->>'agent_id'); v_before:=to_jsonb(old); v_after:=to_jsonb(new);
  else v_id:=coalesce(to_jsonb(new)->>'id',to_jsonb(new)->>'agent_id'); v_after:=to_jsonb(new); end if;
  insert into public.mfa_financial_audit_events(actor_id,table_name,record_id,operation,before_data,after_data)
  values(auth.uid(),tg_table_name,v_id,tg_op,v_before,v_after);
  if tg_op='DELETE' then return old; else return new; end if;
end; $$;
revoke all on function private.mfa_audit_row_change() from public,anon,authenticated;

create or replace function private.mfa_reject_immutable_mutation()
returns trigger language plpgsql set search_path='' as $$
begin raise exception 'This history/ledger table is append-only' using errcode='42501'; end; $$;
revoke all on function private.mfa_reject_immutable_mutation() from public,anon,authenticated;

-- Updated-at triggers.
do $$ declare t text; begin
 foreach t in array array['mfa_agent_trust_badges','mfa_capital_tiers','mfa_agent_capital_profiles','mfa_agent_guarantees','mfa_transactions','mfa_transaction_disputes','mfa_escrow_workflows','mfa_commission_rules'] loop
  execute format('drop trigger if exists %I on public.%I',t||'_touch',t);
  execute format('create trigger %I before update on public.%I for each row execute function private.mfa_touch_updated_at()',t||'_touch',t);
 end loop;
end $$;

-- Audit changes to operational/configuration records.
do $$ declare t text; begin
 foreach t in array array['mfa_agent_trust_badges','mfa_capital_tiers','mfa_agent_capital_profiles','mfa_agent_guarantees','mfa_transactions','mfa_transaction_disputes','mfa_escrow_workflows','mfa_commission_rules'] loop
  execute format('drop trigger if exists %I on public.%I',t||'_audit',t);
  execute format('create trigger %I after insert or update or delete on public.%I for each row execute function private.mfa_audit_row_change()',t||'_audit',t);
 end loop;
end $$;

-- Prevent alteration of transaction history, dispute events, trust history and commission calculations.
create trigger mfa_transaction_history_immutable before update or delete on public.mfa_transaction_status_history
for each row execute function private.mfa_reject_immutable_mutation();
create trigger mfa_dispute_events_immutable before update or delete on public.mfa_dispute_events
for each row execute function private.mfa_reject_immutable_mutation();
create trigger mfa_trust_history_immutable before update or delete on public.mfa_agent_trust_history
for each row execute function private.mfa_reject_immutable_mutation();
create trigger mfa_commission_entries_immutable before update or delete on public.mfa_commission_entries
for each row execute function private.mfa_reject_immutable_mutation();
create trigger mfa_financial_audit_immutable before update or delete on public.mfa_financial_audit_events
for each row execute function private.mfa_reject_immutable_mutation();

-- Summary view runs with invoker permissions and inherits the commission-entry RLS policy.
create or replace view public.mfa_revenue_summary with (security_invoker=true) as
select currency,country_code,partner_id,agent_id,
       sum(agent_commission) as agent_commission_total,
       sum(company_revenue) as company_revenue_total,
       sum(operations_risk_reserve) as operations_reserve_total,
       sum(rounding_remainder) as rounding_remainder_total,
       count(*) as completed_eligible_transactions
from public.mfa_commission_entries
group by currency,country_code,partner_id,agent_id;
grant select on public.mfa_revenue_summary to authenticated;

create index if not exists mfa_transactions_requester_created_idx on public.mfa_transactions(requester_id,created_at desc);
create index if not exists mfa_transactions_agent_status_created_idx on public.mfa_transactions(agent_id,status,created_at desc);
create index if not exists mfa_transactions_partner_created_idx on public.mfa_transactions(partner_id,created_at desc);
create index if not exists mfa_guarantees_agent_status_currency_idx on public.mfa_agent_guarantees(agent_id,verification_status,currency);
create index if not exists mfa_disputes_status_created_idx on public.mfa_transaction_disputes(dispute_status,created_at desc);
create index if not exists mfa_commission_entries_country_currency_idx on public.mfa_commission_entries(country_code,currency,calculated_at desc);
create index if not exists mfa_financial_audit_created_idx on public.mfa_financial_audit_events(created_at desc);

comment on table public.mfa_transactions is 'Tracking-only records. simulation_only is constrained TRUE. This table does not execute, settle, hold or transfer funds.';
comment on table public.mfa_escrow_workflows is 'Escrow readiness metadata only. funds_held and release_executed are constrained FALSE; no escrow provider is connected.';
comment on table public.mfa_commission_entries is 'Immutable commission calculation snapshots. payable is constrained FALSE; no payout or wallet exists.';
