-- MFA Agent CFG Supply & Operational Activation Gate V1.
-- Additive only. CFG remains an external partner/system; this migration does not connect
-- to CFG databases, create an MFA wallet, custody CFG, or execute transfers.
-- An agent is operationally ACTIVE only after MFA verifies at least USD 50 equivalent
-- of CFG Supply through an approved external reference/process.

create table public.mfa_agent_cfg_supply (
  agent_id uuid primary key references public.agent_profiles(id) on delete cascade,
  claimed_supply_usd numeric(20,2) not null default 0 check (claimed_supply_usd >= 0),
  verified_supply_usd numeric(20,2),
  evidence_reference text,
  verification_status text not null default 'pending'
    check (verification_status in ('pending','verified','rejected','suspended')),
  verification_reason text,
  verified_by uuid references auth.users(id),
  verified_at timestamptz,
  last_checked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (verified_supply_usd is null or verified_supply_usd >= 0),
  check (
    (verification_status = 'verified' and verified_supply_usd is not null
      and verified_supply_usd >= 50 and verified_by is not null and verified_at is not null)
    or verification_status <> 'verified'
  )
);

create table public.mfa_agent_cfg_supply_history (
  id bigint generated always as identity primary key,
  agent_id uuid not null references public.agent_profiles(id) on delete cascade,
  previous_status text,
  new_status text not null,
  claimed_supply_usd numeric(20,2) not null,
  verified_supply_usd numeric(20,2),
  evidence_reference text,
  reason text,
  actor_id uuid references auth.users(id),
  created_at timestamptz not null default now()
);

alter table public.mfa_agent_cfg_supply enable row level security;
alter table public.mfa_agent_cfg_supply_history enable row level security;

create policy mfa_cfg_supply_owner_read on public.mfa_agent_cfg_supply
for select to authenticated
using (exists (
  select 1 from public.agent_profiles a
  where a.id = agent_id and a.user_id = (select auth.uid())
));
create policy mfa_cfg_supply_admin_read on public.mfa_agent_cfg_supply
for select to authenticated
using ((select private.current_mfa_role()) = 'super_admin'
  and (select auth.jwt()->>'aal') = 'aal2');
create policy mfa_cfg_supply_admin_update on public.mfa_agent_cfg_supply
for update to authenticated
using ((select private.current_mfa_role()) = 'super_admin'
  and (select auth.jwt()->>'aal') = 'aal2')
with check ((select private.current_mfa_role()) = 'super_admin'
  and (select auth.jwt()->>'aal') = 'aal2');

create policy mfa_cfg_supply_history_owner_read on public.mfa_agent_cfg_supply_history
for select to authenticated
using (exists (
  select 1 from public.agent_profiles a
  where a.id = agent_id and a.user_id = (select auth.uid())
));
create policy mfa_cfg_supply_history_admin_read on public.mfa_agent_cfg_supply_history
for select to authenticated
using ((select private.current_mfa_role()) = 'super_admin'
  and (select auth.jwt()->>'aal') = 'aal2');

revoke all on public.mfa_agent_cfg_supply, public.mfa_agent_cfg_supply_history
from public, anon, authenticated;
grant select on public.mfa_agent_cfg_supply, public.mfa_agent_cfg_supply_history to authenticated;

create or replace function private.mfa_record_cfg_supply_history()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.mfa_agent_cfg_supply_history(
    agent_id, previous_status, new_status, claimed_supply_usd,
    verified_supply_usd, evidence_reference, reason, actor_id
  ) values (
    new.agent_id,
    case when tg_op = 'UPDATE' then old.verification_status else null end,
    new.verification_status,
    new.claimed_supply_usd,
    new.verified_supply_usd,
    new.evidence_reference,
    new.verification_reason,
    auth.uid()
  );
  return new;
end;
$$;
revoke all on function private.mfa_record_cfg_supply_history() from public, anon, authenticated;
create trigger mfa_cfg_supply_history_trigger
after insert or update on public.mfa_agent_cfg_supply
for each row execute function private.mfa_record_cfg_supply_history();

create or replace function private.mfa_reject_cfg_supply_history_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'CFG Supply history is append-only' using errcode = '42501';
end;
$$;
revoke all on function private.mfa_reject_cfg_supply_history_mutation() from public, anon, authenticated;
create trigger mfa_cfg_supply_history_immutable
before update or delete on public.mfa_agent_cfg_supply_history
for each row execute function private.mfa_reject_cfg_supply_history_mutation();

create or replace function public.mfa_submit_agent_cfg_supply(
  p_claimed_supply_usd numeric,
  p_evidence_reference text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_agent_id uuid;
  v_reference text := nullif(trim(coalesce(p_evidence_reference, '')), '');
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if p_claimed_supply_usd is null or p_claimed_supply_usd < 0
    or p_claimed_supply_usd > 1000000000000 then
    raise exception 'Invalid claimed CFG Supply amount' using errcode = '22023';
  end if;
  if v_reference is null or length(v_reference) > 500 then
    raise exception 'A valid external CFG Supply evidence/reference is required' using errcode = '22023';
  end if;
  select id into v_agent_id from public.agent_profiles
  where user_id = auth.uid() for update;
  if v_agent_id is null then
    raise exception 'Agent application not found' using errcode = 'P0002';
  end if;

  insert into public.mfa_agent_cfg_supply(
    agent_id, claimed_supply_usd, verified_supply_usd, evidence_reference,
    verification_status, verification_reason, verified_by, verified_at, last_checked_at
  ) values (
    v_agent_id, p_claimed_supply_usd, null, v_reference,
    'pending', null, null, null, null
  )
  on conflict (agent_id) do update set
    claimed_supply_usd = excluded.claimed_supply_usd,
    verified_supply_usd = null,
    evidence_reference = excluded.evidence_reference,
    verification_status = 'pending',
    verification_reason = null,
    verified_by = null,
    verified_at = null,
    last_checked_at = null,
    updated_at = now();
end;
$$;
revoke all on function public.mfa_submit_agent_cfg_supply(numeric, text) from public, anon;
grant execute on function public.mfa_submit_agent_cfg_supply(numeric, text) to authenticated;

create or replace function public.mfa_review_agent_cfg_supply(
  p_agent_id uuid,
  p_action text,
  p_verified_supply_usd numeric default null,
  p_evidence_reference text default null,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_reason text := nullif(trim(coalesce(p_reason, '')), '');
  v_reference text := nullif(trim(coalesce(p_evidence_reference, '')), '');
begin
  if v_actor is null or coalesce((select auth.jwt())->>'aal', '') <> 'aal2'
    or private.current_mfa_role() is distinct from 'super_admin' then
    raise exception 'AAL2 Super Admin session required' using errcode = '42501';
  end if;
  if p_action not in ('verify', 'reject', 'suspend') then
    raise exception 'Unsupported CFG Supply review action' using errcode = '22023';
  end if;
  if p_action = 'verify' and (
    p_verified_supply_usd is null or p_verified_supply_usd < 50
    or p_verified_supply_usd > 1000000000000
  ) then
    raise exception 'Agent must have at least USD 50 equivalent of verified CFG Supply' using errcode = '23514';
  end if;
  if p_action <> 'verify' and v_reason is null then
    raise exception 'A reason is required for rejection or suspension' using errcode = '22023';
  end if;
  if length(coalesce(v_reason, '')) > 1000 or length(coalesce(v_reference, '')) > 500 then
    raise exception 'Review details exceed permitted length' using errcode = '22023';
  end if;

  update public.mfa_agent_cfg_supply
  set verification_status = case when p_action = 'verify' then 'verified'
    when p_action = 'reject' then 'rejected' else 'suspended' end,
    verified_supply_usd = case when p_action = 'verify' then p_verified_supply_usd else null end,
    evidence_reference = coalesce(v_reference, evidence_reference),
    verification_reason = v_reason,
    verified_by = v_actor,
    verified_at = case when p_action = 'verify' then now() else null end,
    last_checked_at = now(),
    updated_at = now()
  where agent_id = p_agent_id;
  if not found then
    raise exception 'Agent CFG Supply submission not found' using errcode = 'P0002';
  end if;

  insert into public.audit_logs(actor_id, action, entity_type, entity_id, metadata)
  values (
    v_actor, 'agent_cfg_supply_' || p_action, 'agent_cfg_supply', p_agent_id::text,
    jsonb_build_object('verified_supply_usd', case when p_action = 'verify' then p_verified_supply_usd else null end,
      'reason', v_reason, 'evidence_reference', v_reference,
      'minimum_required_usd', 50)
  );
end;
$$;
revoke all on function public.mfa_review_agent_cfg_supply(uuid, text, numeric, text, text) from public, anon;
grant execute on function public.mfa_review_agent_cfg_supply(uuid, text, numeric, text, text) to authenticated;

create or replace view public.mfa_agent_operational_status
with (security_invoker = true)
as
select
  a.id as agent_id,
  a.user_id,
  a.status as verification_status,
  coalesce(s.verification_status, 'not_submitted') as supply_status,
  s.claimed_supply_usd,
  s.verified_supply_usd,
  s.last_checked_at,
  case
    when a.status = 'suspended' then 'suspended'
    when a.status <> 'verified' then 'pending_verification'
    when s.verification_status = 'suspended' then 'suspended'
    when s.verification_status = 'rejected' then 'supply_rejected'
    when s.verification_status = 'verified' and s.verified_supply_usd >= 50 then 'active'
    else 'pending_supply'
  end as operational_status,
  (a.status = 'verified' and s.verification_status = 'verified'
    and s.verified_supply_usd >= 50) as is_active
from public.agent_profiles a
left join public.mfa_agent_cfg_supply s on s.agent_id = a.id;

revoke all on public.mfa_agent_operational_status from public, anon;
grant select on public.mfa_agent_operational_status to authenticated;

create or replace function private.mfa_require_active_cfg_supply()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.agent_id is null then
    return new;
  end if;
  if not exists (
    select 1
    from public.agent_profiles a
    join public.mfa_agent_cfg_supply s on s.agent_id = a.id
    where a.id = new.agent_id
      and a.status = 'verified'
      and s.verification_status = 'verified'
      and s.verified_supply_usd >= 50
  ) then
    raise exception 'Agent must be verified and maintain at least USD 50 equivalent CFG Supply before receiving transactions'
      using errcode = '42501';
  end if;
  return new;
end;
$$;
revoke all on function private.mfa_require_active_cfg_supply() from public, anon, authenticated;
create trigger mfa_agent_minimum_cfg_supply_gate
before insert or update of agent_id on public.mfa_transactions
for each row execute function private.mfa_require_active_cfg_supply();

-- This migration deliberately does not change transaction_enabled, simulation_only,
-- escrow hard stops, or commission payable hard stops. Real-money activation is a separate
-- controlled release after licensed-provider integration, legal review and staging tests.
