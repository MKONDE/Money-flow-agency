-- MFA Agent Trust, Capital & Commission Engine V1: guarded workflows and ledgers.
-- Trigger functions live in the non-exposed private schema and are not public RPC endpoints.

create or replace function private.mfa_touch_updated_at()
returns trigger language plpgsql set search_path='' as $$
begin
  new.updated_at=now();
  return new;
end;
$$;
revoke all on function private.mfa_touch_updated_at() from public,anon,authenticated;

create or replace function private.mfa_seed_agent_trust_badge()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  insert into public.mfa_agent_trust_badges(agent_id,trust_level,badge_status)
  values(new.id,'independent_agent','active') on conflict(agent_id) do nothing;
  return new;
end;
$$;
revoke all on function private.mfa_seed_agent_trust_badge() from public,anon,authenticated;
create trigger mfa_seed_agent_trust_badge after insert on public.agent_profiles
for each row execute function private.mfa_seed_agent_trust_badge();

create or replace function private.mfa_guard_trust_badge_change()
returns trigger language plpgsql security definer set search_path='' as $$
declare
  v_agent_status text;
  v_declared numeric(20,2);
  v_currency char(3);
  v_verified_guarantee numeric(20,2);
  v_guarantee_expiry date;
  v_has_indefinite boolean;
begin
  select status into v_agent_status from public.agent_profiles where id=new.agent_id;
  if new.badge_status='active' and new.trust_level<>'independent_agent' and v_agent_status is distinct from 'verified' then
    raise exception 'Trust levels above Independent Agent require a verified agent profile' using errcode='42501';
  end if;
  if new.badge_status='active' and new.trust_level='capital_backed_agent' then
    select declared_capital,currency into v_declared,v_currency from public.mfa_agent_capital_profiles where agent_id=new.agent_id;
    select coalesce(sum(g.amount),0),max(g.valid_until),coalesce(bool_or(g.valid_until is null),false)
      into v_verified_guarantee,v_guarantee_expiry,v_has_indefinite from public.mfa_agent_guarantees g
      join public.mfa_agent_capital_profiles cp on cp.agent_id=g.agent_id and cp.currency=g.currency
      where g.agent_id=new.agent_id and g.currency=v_currency and g.verification_status='verified'
      and (g.valid_from is null or g.valid_from<=current_date) and (g.valid_until is null or g.valid_until>=current_date);
    if coalesce(v_declared,0)<=0 or v_verified_guarantee<=0 then
      raise exception 'Capital-Backed Agent requires declared capital and a separately verified guarantee in the declared currency' using errcode='23514';
    end if;
    if not v_has_indefinite and v_guarantee_expiry is not null and (new.valid_until is null or new.valid_until::date>v_guarantee_expiry) then
      new.valid_until:=v_guarantee_expiry::timestamptz;
    end if;
  end if;
  if tg_op='UPDATE' then
    if old.trust_level is distinct from new.trust_level or old.badge_status is distinct from new.badge_status then
      insert into public.mfa_agent_trust_history(agent_id,previous_level,new_level,badge_status,reason,actor_id)
      values(new.agent_id,old.trust_level,new.trust_level,new.badge_status,new.reason,auth.uid());
    end if;
  end if;
  return new;
end;
$$;
revoke all on function private.mfa_guard_trust_badge_change() from public,anon,authenticated;
create trigger mfa_trust_badge_guard before insert or update on public.mfa_agent_trust_badges
for each row execute function private.mfa_guard_trust_badge_change();


create or replace function private.mfa_guard_capital_declaration()
returns trigger language plpgsql security definer set search_path='' as $
declare v_level text; v_badge_status text;
begin
  select trust_level,badge_status into v_level,v_badge_status
  from public.mfa_agent_trust_badges where agent_id=new.agent_id;
  if v_level='capital_backed_agent' and v_badge_status='active' then
    if new.declared_capital<=0 or not exists(
      select 1 from public.mfa_agent_guarantees g
      where g.agent_id=new.agent_id and g.currency=new.currency and g.verification_status='verified'
      and (g.valid_from is null or g.valid_from<=current_date)
      and (g.valid_until is null or g.valid_until>=current_date)
    ) then
      raise exception 'Suspend or demote the Capital-Backed badge before changing its qualifying capital declaration' using errcode='23514';
    end if;
  end if;
  return new;
end;
$;
revoke all on function private.mfa_guard_capital_declaration() from public,anon,authenticated;
create trigger mfa_capital_declaration_guard before insert or update on public.mfa_agent_capital_profiles
for each row execute function private.mfa_guard_capital_declaration();

create or replace function private.mfa_guard_guarantee_review()
returns trigger language plpgsql security definer set search_path='' as $
begin
  if new.verification_status='verified' then
    if new.verified_by is null or new.verified_at is null
      or (new.valid_from is not null and new.valid_from>current_date)
      or (new.valid_until is not null and new.valid_until<current_date) then
      raise exception 'A guarantee can only be verified with reviewer identity and a currently valid date range' using errcode='23514';
    end if;
  end if;

  if old.verification_status='verified' and (
    new.verification_status<>'verified'
    or new.currency is distinct from old.currency
    or (new.valid_from is not null and new.valid_from>current_date)
    or (new.valid_until is not null and new.valid_until<current_date)
  ) then
    update public.mfa_agent_trust_badges
    set badge_status='suspended',
        reason='Capital guarantee status or validity changed; badge automatically suspended'
    where agent_id=new.agent_id and trust_level='capital_backed_agent' and badge_status='active';
  end if;
  return new;
end;
$;
revoke all on function private.mfa_guard_guarantee_review() from public,anon,authenticated;
create trigger mfa_guarantee_review_guard before update on public.mfa_agent_guarantees
for each row execute function private.mfa_guard_guarantee_review();

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
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(new.agent_id::text,0));
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
   order by minimum_verified_guarantee desc,minimum_declared_capital desc,max_per_transaction asc,effective_from desc limit 1;
  if not found then raise exception 'No active capital tier matches this agent declaration and verified guarantee' using errcode='23514'; end if;
  if new.amount>v_tier.max_per_transaction then raise exception 'Transaction exceeds agent per-transaction limit' using errcode='23514'; end if;

  select coalesce(sum(t.amount),0) into v_pending from public.mfa_transactions t
   where t.agent_id=new.agent_id and t.currency=new.currency
   and t.status in ('CREATED','PENDING_AGENT','PAYMENT_PENDING','PAYMENT_SUBMITTED','UNDER_REVIEW','CONFIRMED','DISPUTED')
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
end;
$$;
revoke all on function private.mfa_enforce_agent_transaction_limits() from public,anon,authenticated;
create trigger mfa_agent_transaction_limits before insert or update of agent_id,amount,currency
on public.mfa_transactions for each row execute function private.mfa_enforce_agent_transaction_limits();

create or replace function private.mfa_validate_transaction_transition()
returns trigger language plpgsql security definer set search_path='' as $$
declare
  v_role text:=private.current_mfa_role();
  v_agent_user uuid;
  v_agent_status text;
  v_recent_requests integer;
begin
  if tg_op='INSERT' then
    if new.status<>'CREATED' or new.simulation_only is not true or new.commissionable_amount<>0 then
      raise exception 'Customer transaction submissions must begin as simulation-only CREATED records' using errcode='42501';
    end if;
    if v_role is distinct from 'super_admin' then
      perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(new.requester_id::text,0));
      select count(*) into v_recent_requests from public.mfa_transactions
        where requester_id=new.requester_id and created_at>now()-interval '1 hour';
      if v_recent_requests>=20 then
        raise exception 'MFA tracking request rate limit reached. Try again later.' using errcode='54000';
      end if;
    end if;
    return new;
  end if;

  if new.agent_id is distinct from old.agent_id and not (v_role='super_admin' and (select auth.jwt()->>'aal')='aal2') then
    raise exception 'Only an AAL2 Super Admin may assign or reassign an agent' using errcode='42501';
  end if;

  if not (v_role='super_admin' and (select auth.jwt()->>'aal')='aal2') then
    select user_id,status into v_agent_user,v_agent_status from public.agent_profiles where id=old.agent_id;
    if v_agent_user is distinct from auth.uid() or v_agent_status is distinct from 'verified' then
      raise exception 'Only the verified assigned agent may update tracking progress' using errcode='42501';
    end if;
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
      raise exception 'Only an AAL2 Super Admin may edit transaction tracking metadata' using errcode='42501';
    end if;
  end if;

  if new.status is distinct from old.status then
    if v_role='super_admin' and (select auth.jwt()->>'aal')='aal2' then
      if not ((old.status='CREATED' and new.status in ('PENDING_AGENT','CANCELLED','EXPIRED'))
        or (old.status='PENDING_AGENT' and new.status in ('PAYMENT_PENDING','REJECTED','CANCELLED','EXPIRED'))
        or (old.status='PAYMENT_PENDING' and new.status in ('PAYMENT_SUBMITTED','REJECTED','CANCELLED','EXPIRED'))
        or (old.status='PAYMENT_SUBMITTED' and new.status in ('UNDER_REVIEW','DISPUTED','REJECTED'))
        or (old.status='UNDER_REVIEW' and new.status in ('CONFIRMED','REJECTED','DISPUTED'))
        or (old.status='CONFIRMED' and new.status in ('COMPLETED','DISPUTED'))
        or (old.status='COMPLETED' and new.status='DISPUTED')
        or (old.status='DISPUTED' and new.status in ('CONFIRMED','REJECTED','CANCELLED'))) then
        raise exception 'Invalid transaction status transition' using errcode='22023';
      end if;
    else
      if new.status='DISPUTED' and exists(
        select 1 from public.mfa_transaction_disputes d
        where d.transaction_id=old.id and d.opened_by=auth.uid() and d.dispute_status='open'
      ) then
        null;
      elsif v_agent_user is distinct from auth.uid() or v_agent_status is distinct from 'verified' or not (
        (old.status='PENDING_AGENT' and new.status='PAYMENT_PENDING')
        or (old.status='PAYMENT_PENDING' and new.status='PAYMENT_SUBMITTED')
      ) then
        raise exception 'Agent may only advance an assigned request; disputes use the dispute form' using errcode='42501';
      end if;
    end if;
  end if;
  return new;
end;
$$;
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
end;
$$;
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
  if new.status<>'COMPLETED' or new.agent_id is null or new.commissionable_amount<=0 then return new; end if;
  if old.commission_calculated is true or new.commission_calculated is true then return new; end if;
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
  if not found or new.commissionable_amount<v_rule.minimum_commission_pool then return new; end if;

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
end;
$$;
revoke all on function private.mfa_create_commission_entry() from public,anon,authenticated;
create trigger mfa_transaction_commission_calculation after update of status,commissionable_amount,agent_id
on public.mfa_transactions for each row execute function private.mfa_create_commission_entry();

create or replace function private.mfa_open_dispute_on_insert()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_status text;
begin
  select status into v_status from public.mfa_transactions where id=new.transaction_id for update;
  if v_status not in ('PAYMENT_SUBMITTED','UNDER_REVIEW','CONFIRMED','COMPLETED') then
    raise exception 'A dispute can only be opened after payment evidence has been submitted' using errcode='22023';
  end if;
  update public.mfa_transactions set status='DISPUTED' where id=new.transaction_id;
  insert into public.mfa_dispute_events(dispute_id,actor_id,event_type,note)
  values(new.id,new.opened_by,'dispute_opened',new.reason_code);
  return new;
end;
$$;
revoke all on function private.mfa_open_dispute_on_insert() from public,anon,authenticated;
create trigger mfa_dispute_opened after insert on public.mfa_transaction_disputes
for each row execute function private.mfa_open_dispute_on_insert();

create or replace function private.mfa_record_dispute_update()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if new.dispute_status is distinct from old.dispute_status or new.resolution_note is distinct from old.resolution_note then
    insert into public.mfa_dispute_events(dispute_id,actor_id,event_type,note)
    values(new.id,auth.uid(),'dispute_'||new.dispute_status,new.resolution_note);
  end if;
  return new;
end;
$$;
revoke all on function private.mfa_record_dispute_update() from public,anon,authenticated;
create trigger mfa_dispute_update_event after update on public.mfa_transaction_disputes
for each row execute function private.mfa_record_dispute_update();

create or replace function private.mfa_guard_escrow_update()
returns trigger language plpgsql security definer set search_path='' as $$
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
end;
$$;
revoke all on function private.mfa_guard_escrow_update() from public,anon,authenticated;
create trigger mfa_escrow_update_guard before update on public.mfa_escrow_workflows
for each row execute function private.mfa_guard_escrow_update();

create or replace function private.mfa_audit_row_change()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_id text; v_before jsonb; v_after jsonb;
begin
  if tg_op='DELETE' then
    v_id:=coalesce(to_jsonb(old)->>'id',to_jsonb(old)->>'agent_id',to_jsonb(old)->>'country_code'); v_before:=to_jsonb(old);
  elsif tg_op='UPDATE' then
    v_id:=coalesce(to_jsonb(new)->>'id',to_jsonb(new)->>'agent_id',to_jsonb(new)->>'country_code'); v_before:=to_jsonb(old); v_after:=to_jsonb(new);
  else
    v_id:=coalesce(to_jsonb(new)->>'id',to_jsonb(new)->>'agent_id'); v_after:=to_jsonb(new);
  end if;
  insert into public.mfa_financial_audit_events(actor_id,table_name,record_id,operation,before_data,after_data)
  values(auth.uid(),tg_table_name,v_id,tg_op,v_before,v_after);
  if tg_op='DELETE' then return old; else return new; end if;
end;
$$;
revoke all on function private.mfa_audit_row_change() from public,anon,authenticated;

create or replace function private.mfa_reject_immutable_mutation()
returns trigger language plpgsql set search_path='' as $$
begin
  raise exception 'This history/ledger table is append-only' using errcode='42501';
end;
$$;
revoke all on function private.mfa_reject_immutable_mutation() from public,anon,authenticated;

do $$
declare t text;
begin
  foreach t in array array['mfa_country_settings','mfa_agent_trust_badges','mfa_capital_tiers','mfa_agent_capital_profiles',
    'mfa_agent_guarantees','mfa_transactions','mfa_transaction_disputes','mfa_escrow_workflows','mfa_commission_rules'] loop
    execute format('drop trigger if exists %I on public.%I',t||'_touch',t);
    execute format('create trigger %I before update on public.%I for each row execute function private.mfa_touch_updated_at()',t||'_touch',t);
    execute format('drop trigger if exists %I on public.%I',t||'_audit',t);
    execute format('create trigger %I after insert or update or delete on public.%I for each row execute function private.mfa_audit_row_change()',t||'_audit',t);
  end loop;
end;
$$;

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

create or replace view public.mfa_agent_exposure_summary with (security_invoker=true) as
select agent_id,currency,
  coalesce(sum(amount) filter(where status in ('CREATED','PENDING_AGENT','PAYMENT_PENDING','PAYMENT_SUBMITTED','UNDER_REVIEW','CONFIRMED','DISPUTED')),0) as pending_exposure,
  coalesce(sum(amount) filter(where created_at>=date_trunc('day',now()) and status not in ('REJECTED','CANCELLED','EXPIRED')),0) as daily_volume,
  coalesce(sum(amount) filter(where created_at>=date_trunc('month',now()) and status not in ('REJECTED','CANCELLED','EXPIRED')),0) as monthly_volume,
  count(*) filter(where status in ('PENDING_AGENT','PAYMENT_PENDING','PAYMENT_SUBMITTED','UNDER_REVIEW','CONFIRMED','DISPUTED')) as pending_transaction_count
from public.mfa_transactions
where agent_id is not null
group by agent_id,currency;
grant select on public.mfa_agent_exposure_summary to authenticated;

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

comment on table public.mfa_transactions is 'Tracking-only records. simulation_only is constrained TRUE. No settlement, custody, funds holding or transfers.';
comment on table public.mfa_escrow_workflows is 'Escrow readiness metadata only. funds_held and release_executed are constrained FALSE; no provider is connected.';
comment on table public.mfa_commission_entries is 'Immutable calculation snapshots. payable is constrained FALSE; no payout or wallet exists.';
