-- MFA Agent Trust, Capital & Commission Engine V1 schema smoke tests.
-- Run AFTER all migrations on the dedicated MFA test/staging database.
-- This script is read-only and raises an exception if required guards are absent.

do $$
declare
  v_missing text;
  v_count integer;
begin
  select string_agg(t.table_name, ', ') into v_missing
  from (values
    ('mfa_country_settings'),('mfa_agent_trust_badges'),('mfa_agent_trust_history'),
    ('mfa_capital_tiers'),('mfa_agent_capital_profiles'),('mfa_agent_guarantees'),
    ('mfa_transactions'),('mfa_transaction_status_history'),('mfa_transaction_disputes'),
    ('mfa_dispute_events'),('mfa_escrow_workflows'),('mfa_commission_rules'),
    ('mfa_commission_entries'),('mfa_financial_audit_events')
  ) as t(table_name)
  where not exists(select 1 from information_schema.tables i where i.table_schema='public' and i.table_name=t.table_name);
  if v_missing is not null then raise exception 'Missing MFA module tables: %',v_missing; end if;

  select count(*) into v_count
  from pg_catalog.pg_class c
  join pg_catalog.pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public'
    and c.relname in ('mfa_country_settings','mfa_agent_trust_badges','mfa_agent_trust_history',
      'mfa_capital_tiers','mfa_agent_capital_profiles','mfa_agent_guarantees','mfa_transactions',
      'mfa_transaction_status_history','mfa_transaction_disputes','mfa_dispute_events',
      'mfa_escrow_workflows','mfa_commission_rules','mfa_commission_entries','mfa_financial_audit_events')
    and c.relrowsecurity;
  if v_count<>14 then raise exception 'Expected RLS on 14 MFA module tables; found %',v_count; end if;

  if not exists(select 1 from public.mfa_commission_rules
    where scope_type='global' and scope_key='*' and currency is null
      and agent_share_pct=70 and company_share_pct=20 and operations_reserve_pct=10 and enabled) then
    raise exception 'Default 70/20/10 commission rule is missing';
  end if;

  if not exists(select 1 from pg_catalog.pg_constraint c join pg_catalog.pg_class t on t.oid=c.conrelid
    join pg_catalog.pg_namespace n on n.oid=t.relnamespace
    where n.nspname='public' and t.relname='mfa_transactions' and pg_catalog.pg_get_constraintdef(c.oid) ilike '%simulation_only = true%') then
    raise exception 'Tracking-only transaction constraint is missing';
  end if;
  if not exists(select 1 from pg_catalog.pg_constraint c join pg_catalog.pg_class t on t.oid=c.conrelid
    join pg_catalog.pg_namespace n on n.oid=t.relnamespace
    where n.nspname='public' and t.relname='mfa_escrow_workflows' and pg_catalog.pg_get_constraintdef(c.oid) ilike '%funds_held = false%') then
    raise exception 'Escrow funds-held hard stop is missing';
  end if;
  if not exists(select 1 from pg_catalog.pg_constraint c join pg_catalog.pg_class t on t.oid=c.conrelid
    join pg_catalog.pg_namespace n on n.oid=t.relnamespace
    where n.nspname='public' and t.relname='mfa_escrow_workflows' and pg_catalog.pg_get_constraintdef(c.oid) ilike '%release_executed = false%') then
    raise exception 'Escrow release hard stop is missing';
  end if;
  if not exists(select 1 from pg_catalog.pg_constraint c join pg_catalog.pg_class t on t.oid=c.conrelid
    join pg_catalog.pg_namespace n on n.oid=t.relnamespace
    where n.nspname='public' and t.relname='mfa_commission_entries' and pg_catalog.pg_get_constraintdef(c.oid) ilike '%payable = false%') then
    raise exception 'Commission non-payable hard stop is missing';
  end if;

  if not exists(select 1 from pg_catalog.pg_trigger where tgname='mfa_transaction_status_history_trigger' and not tgisinternal) then
    raise exception 'Immutable transaction status history trigger is missing';
  end if;
  if not exists(select 1 from pg_catalog.pg_trigger where tgname='mfa_transaction_commission_calculation' and not tgisinternal) then
    raise exception 'Commission calculation trigger is missing';
  end if;
  if not exists(select 1 from pg_catalog.pg_trigger where tgname='mfa_transaction_history_immutable' and not tgisinternal) then
    raise exception 'Transaction history immutability trigger is missing';
  end if;
  if not exists(select 1 from pg_catalog.pg_views where schemaname='public' and viewname='mfa_revenue_summary') then
    raise exception 'Revenue summary view is missing';
  end if;
  if not exists(select 1 from pg_catalog.pg_views where schemaname='public' and viewname='mfa_agent_exposure_summary') then
    raise exception 'Agent exposure summary view is missing';
  end if;
  if not exists(select 1 from pg_catalog.pg_trigger where tgname='mfa_dispute_update_guard' and not tgisinternal) then
    raise exception 'Dispute decision guard trigger is missing';
  end if;
  if not exists(select 1 from pg_catalog.pg_trigger where tgname='mfa_guarantee_review_guard' and not tgisinternal) then
    raise exception 'Guarantee review guard trigger is missing';
  end if;
  if not exists(select 1 from pg_catalog.pg_trigger where tgname='mfa_capital_declaration_guard' and not tgisinternal) then
    raise exception 'Capital declaration guard trigger is missing';
  end if;
  if not exists(select 1 from pg_catalog.pg_indexes where schemaname='public' and indexname='mfa_disputes_one_per_transaction_idx') then
    raise exception 'Unique one-dispute-per-transaction index is missing';
  end if;

  if not exists(select 1 from pg_catalog.pg_policy where polname='mfa_transactions_admin_all') then
    raise exception 'AAL2 Super Admin transaction policy is missing';
  end if;
  if to_regclass('public.service_requests') is not null then
    if has_table_privilege('anon','public.service_requests','SELECT')
      or has_table_privilege('anon','public.service_requests','INSERT')
      or has_table_privilege('anon','public.service_requests','UPDATE') then
      raise exception 'Anon still has privileges on legacy service_requests';
    end if;
    if exists(select 1 from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace
      where n.nspname='public' and p.proname='agent_update_service_request' and p.prosecdef) then
      raise exception 'Legacy agent request RPC is still SECURITY DEFINER';
    end if;
    if not exists(select 1 from pg_catalog.pg_policy where polname='service_requests_assigned_agent_update') then
      raise exception 'Legacy assigned-agent update RLS policy is missing';
    end if;
  end if;


  if not exists(select 1 from information_schema.tables
    where table_schema='public' and table_name='mfa_agent_cfg_supply') then
    raise exception 'Agent CFG Supply verification table is missing';
  end if;
  if not exists(select 1 from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relname='mfa_agent_cfg_supply' and c.relrowsecurity) then
    raise exception 'Agent CFG Supply RLS is missing';
  end if;
  if has_table_privilege('authenticated','public.mfa_agent_cfg_supply','UPDATE') then
    raise exception 'Agents must not directly update verified CFG Supply fields';
  end if;
  if not exists(select 1 from pg_catalog.pg_constraint c
    join pg_catalog.pg_class t on t.oid=c.conrelid
    join pg_catalog.pg_namespace n on n.oid=t.relnamespace
    where n.nspname='public' and t.relname='mfa_agent_cfg_supply'
      and pg_catalog.pg_get_constraintdef(c.oid) ilike '%verified_supply_usd >= 50%') then
    raise exception 'Minimum USD 50 verified CFG Supply constraint is missing';
  end if;
  if not exists(select 1 from pg_catalog.pg_trigger
    where tgname='mfa_agent_minimum_cfg_supply_gate' and not tgisinternal) then
    raise exception 'Agent transaction minimum CFG Supply gate is missing';
  end if;
  if not exists(select 1 from pg_catalog.pg_views
    where schemaname='public' and viewname='mfa_agent_operational_status') then
    raise exception 'Agent operational activation status view is missing';
  end if;
  if not has_function_privilege('authenticated','public.mfa_submit_agent_cfg_supply(numeric,text)','EXECUTE')
    or not has_function_privilege('authenticated','public.mfa_review_agent_cfg_supply(uuid,text,numeric,text,text)','EXECUTE') then
    raise exception 'CFG Supply submission/review RPC permissions are missing';
  end if;

  if exists(select 1 from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relkind='r' and c.relname ilike 'mfa_wallet%') then
    raise exception 'Unexpected wallet table found in MFA public schema';
  end if;
end;
$$;

select 'MFA Agent Trust, Capital & Commission schema smoke tests passed.' as test_result;
