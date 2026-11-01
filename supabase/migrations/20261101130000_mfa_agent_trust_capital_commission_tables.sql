-- MFA Agent Trust, Capital & Commission Engine V1: additive data model.
-- Apply only to the dedicated money-flow-agency Supabase project.
-- This migration creates no customer wallet, stored-value account, custody or payment execution.

create schema if not exists private;

create table public.mfa_country_settings (
  country_code char(2) primary key,
  country_name text not null,
  default_currency char(3) not null,
  supported_currencies text[] not null default '{}',
  enabled boolean not null default true,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.mfa_agent_trust_badges (
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
create table public.mfa_agent_trust_history (
  id bigint generated always as identity primary key,
  agent_id uuid not null references public.agent_profiles(id) on delete cascade,
  previous_level text,
  new_level text not null,
  badge_status text not null,
  reason text,
  actor_id uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create table public.mfa_capital_tiers (
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
create table public.mfa_agent_capital_profiles (
  agent_id uuid primary key references public.agent_profiles(id) on delete cascade,
  currency char(3) not null,
  declared_capital numeric(20,2) not null check (declared_capital >= 0),
  declared_transaction_float numeric(20,2) not null default 0 check (declared_transaction_float >= 0),
  declaration_notes text,
  submitted_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.mfa_agent_guarantees (
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

create table public.mfa_transactions (
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
create table public.mfa_transaction_status_history (
  id bigint generated always as identity primary key,
  transaction_id uuid not null references public.mfa_transactions(id) on delete restrict,
  previous_status text,
  new_status text not null,
  actor_id uuid references auth.users(id),
  actor_role text,
  note text,
  created_at timestamptz not null default now()
);

create table public.mfa_transaction_disputes (
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
create table public.mfa_dispute_events (
  id bigint generated always as identity primary key,
  dispute_id uuid not null references public.mfa_transaction_disputes(id) on delete restrict,
  actor_id uuid references auth.users(id),
  event_type text not null,
  note text,
  created_at timestamptz not null default now()
);

-- Metadata-only preparation. There is no escrow amount, balance, custody or release execution.
create table public.mfa_escrow_workflows (
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

create table public.mfa_commission_rules (
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
create unique index mfa_commission_rules_scope_effective_idx
  on public.mfa_commission_rules(scope_type,scope_key,coalesce(currency,'*'),effective_from);
create table public.mfa_commission_entries (
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
create table public.mfa_financial_audit_events (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users(id),
  table_name text not null,
  record_id text,
  operation text not null check (operation in ('INSERT','UPDATE','DELETE')),
  before_data jsonb,
  after_data jsonb,
  created_at timestamptz not null default now()
);

insert into public.mfa_commission_rules(rule_name,scope_type,scope_key,agent_share_pct,company_share_pct,operations_reserve_pct)
values ('MFA Global Default 70/20/10','global','*',70,20,10);
insert into public.mfa_agent_trust_badges(agent_id,trust_level,badge_status)
select id,'independent_agent','active' from public.agent_profiles;
