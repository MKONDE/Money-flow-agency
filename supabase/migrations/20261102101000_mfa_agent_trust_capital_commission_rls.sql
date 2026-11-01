-- MFA Agent Trust, Capital & Commission Engine V1: RLS and least-privilege grants.
-- Admin write policies require both the database role and AAL2.

alter table public.mfa_country_settings enable row level security;
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

create policy mfa_country_public_read on public.mfa_country_settings for select to anon,authenticated using (enabled=true);
create policy mfa_country_admin_all on public.mfa_country_settings for all to authenticated
using ((select private.current_mfa_role())='super_admin' and (select auth.jwt()->>'aal')='aal2')
with check ((select private.current_mfa_role())='super_admin' and (select auth.jwt()->>'aal')='aal2');

create policy mfa_trust_public_read on public.mfa_agent_trust_badges for select to anon,authenticated
using (badge_status='active' and (valid_until is null or valid_until>now())
  and exists(select 1 from public.agent_profiles a where a.id=agent_id and a.status='verified'));
create policy mfa_trust_owner_read on public.mfa_agent_trust_badges for select to authenticated
using (exists(select 1 from public.agent_profiles a where a.id=agent_id and a.user_id=(select auth.uid())));
create policy mfa_trust_admin_all on public.mfa_agent_trust_badges for all to authenticated
using ((select private.current_mfa_role())='super_admin' and (select auth.jwt()->>'aal')='aal2')
with check ((select private.current_mfa_role())='super_admin' and (select auth.jwt()->>'aal')='aal2');
create policy mfa_trust_history_admin_read on public.mfa_agent_trust_history for select to authenticated
using ((select private.current_mfa_role())='super_admin' and (select auth.jwt()->>'aal')='aal2');

create policy mfa_tiers_authenticated_read on public.mfa_capital_tiers for select to authenticated using (enabled=true);
create policy mfa_tiers_admin_all on public.mfa_capital_tiers for all to authenticated
using ((select private.current_mfa_role())='super_admin' and (select auth.jwt()->>'aal')='aal2')
with check ((select private.current_mfa_role())='super_admin' and (select auth.jwt()->>'aal')='aal2');

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

create policy mfa_transactions_customer_read on public.mfa_transactions for select to authenticated
using (requester_id=(select auth.uid()));
create policy mfa_transactions_agent_read on public.mfa_transactions for select to authenticated
using (exists(select 1 from public.agent_profiles a where a.id=agent_id and a.user_id=(select auth.uid())));
create policy mfa_transactions_partner_read on public.mfa_transactions for select to authenticated
using (exists(select 1 from public.business_partners p where p.id=partner_id and p.owner_user_id=(select auth.uid())));
create policy mfa_transactions_customer_insert on public.mfa_transactions for insert to authenticated
with check (requester_id=(select auth.uid()) and agent_id is null and status='CREATED'
  and simulation_only=true and commissionable_amount=0);
create policy mfa_transactions_agent_update on public.mfa_transactions for update to authenticated
using (exists(select 1 from public.agent_profiles a where a.id=agent_id and a.user_id=(select auth.uid())))
with check (exists(select 1 from public.agent_profiles a where a.id=agent_id and a.user_id=(select auth.uid())));
create policy mfa_transactions_admin_all on public.mfa_transactions for all to authenticated
using ((select private.current_mfa_role())='super_admin' and (select auth.jwt()->>'aal')='aal2')
with check ((select private.current_mfa_role())='super_admin' and (select auth.jwt()->>'aal')='aal2');

create policy mfa_transaction_history_owner_read on public.mfa_transaction_status_history for select to authenticated
using (exists(select 1 from public.mfa_transactions t where t.id=transaction_id and
  (t.requester_id=(select auth.uid()) or exists(select 1 from public.agent_profiles a where a.id=t.agent_id and a.user_id=(select auth.uid()))
   or exists(select 1 from public.business_partners p where p.id=t.partner_id and p.owner_user_id=(select auth.uid())))));
create policy mfa_transaction_history_admin_read on public.mfa_transaction_status_history for select to authenticated
using ((select private.current_mfa_role())='super_admin' and (select auth.jwt()->>'aal')='aal2');

create policy mfa_disputes_owner_read on public.mfa_transaction_disputes for select to authenticated
using (opened_by=(select auth.uid()) or exists(select 1 from public.mfa_transactions t where t.id=transaction_id and
  (t.requester_id=(select auth.uid()) or exists(select 1 from public.agent_profiles a where a.id=t.agent_id and a.user_id=(select auth.uid()))
   or exists(select 1 from public.business_partners p where p.id=t.partner_id and p.owner_user_id=(select auth.uid())))));
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

revoke all on public.mfa_country_settings,public.mfa_agent_trust_badges,public.mfa_agent_trust_history,
 public.mfa_capital_tiers,public.mfa_agent_capital_profiles,public.mfa_agent_guarantees,
 public.mfa_transactions,public.mfa_transaction_status_history,public.mfa_transaction_disputes,
 public.mfa_dispute_events,public.mfa_escrow_workflows,public.mfa_commission_rules,
 public.mfa_commission_entries,public.mfa_financial_audit_events from public,anon,authenticated;

grant select on public.mfa_country_settings to anon,authenticated;
grant insert,update on public.mfa_country_settings to authenticated;
grant select on public.mfa_agent_trust_badges to anon,authenticated;
grant insert,update on public.mfa_agent_trust_badges to authenticated;
grant select on public.mfa_agent_trust_history to authenticated;
grant select,insert,update on public.mfa_capital_tiers to authenticated;
grant select,insert,update on public.mfa_agent_capital_profiles to authenticated;
grant select,insert,update on public.mfa_agent_guarantees to authenticated;
grant select,insert,update on public.mfa_transactions to authenticated;
grant select on public.mfa_transaction_status_history,public.mfa_dispute_events to authenticated;
grant select,insert,update on public.mfa_transaction_disputes to authenticated;
grant select,insert,update on public.mfa_escrow_workflows to authenticated;
grant select,insert,update on public.mfa_commission_rules to authenticated;
grant select on public.mfa_commission_entries,public.mfa_financial_audit_events to authenticated;

-- Column grants: agents can edit only their declared figures and limited transaction progress.
revoke update on public.mfa_agent_capital_profiles from authenticated;
grant update(currency,declared_capital,declared_transaction_float,declaration_notes)
  on public.mfa_agent_capital_profiles to authenticated;
revoke update on public.mfa_transactions from authenticated;
grant update(agent_id,partner_id,service_code,country_code,currency,payment_network,amount,commissionable_amount,
  customer_reference,agent_reference,partner_reference,status,evidence_reference,customer_note)
  on public.mfa_transactions to authenticated;
revoke insert on public.mfa_transactions from authenticated;
grant insert(requester_id,partner_id,service_code,country_code,currency,payment_network,amount,
  customer_reference,customer_note,simulation_only) on public.mfa_transactions to authenticated;
revoke update on public.mfa_transaction_disputes from authenticated;
grant update(dispute_status,resolution_note,resolved_by,resolved_at) on public.mfa_transaction_disputes to authenticated;
grant update(customer_confirmed_at) on public.mfa_escrow_workflows to authenticated;
