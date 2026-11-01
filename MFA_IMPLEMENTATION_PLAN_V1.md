# MFA Implementation Plan — Agent Trust, Capital & Commission Engine V1

**Project:** Money Flow Agency  
**Base branch:** main  
**Working branch:** feature/agent-trust-capital-commission-v1  
**Baseline:** MFA Master Blueprint V1 + additive V1.1  
**Date:** 2026-11-01

## Non-negotiable boundaries

- MFA is an independent multi-partner platform. CFG is one partner only.
- Never connect to CFG/CFGG databases, wallets, balances or ledgers.
- Do not create an MFA token, coin, customer wallet or stored-value balance.
- Do not hold customer funds or accept real deposits.
- Do not activate real payment execution, withdrawal, transfer, escrow holding or escrow release.
- Preserve existing architecture and data. All work is additive.
- Work only on feature branches. No direct main commits, merge or production deployment without owner approval.
- Never expose or commit .env files or secrets.

## V1 module delivery

### 1. Global Agent Network
- [x] Existing registration and agent profile reused.
- [x] Capture supported payment networks at application.
- [x] Search public verified directory by business name, country and city.
- [x] Online/offline presence synced to public directory.
- [x] Public phone/email shown only after explicit agent consent.
- [ ] Agent logo/profile image upload via a dedicated validated Storage bucket.
- [ ] Service/language/network filters beyond name/country/city.

### 2. Agent Verification and Trust
- [x] Reuse existing Super Admin AAL2 verification workflow.
- [x] Add Independent, Verified, Capital-Backed, Premium and Strategic trust levels.
- [x] Admin badge activation, suspension and revocation.
- [x] Capital-Backed eligibility requires declared capital and separately verified in-date guarantee.
- [x] Append-only trust badge history and audit events.

### 3. Agent Capital Guarantee
- [x] Record declared capital and declared transaction float separately.
- [x] Record documentary guarantee references separately.
- [x] Admin verification/rejection of guarantee references.
- [x] Admin-configurable currency-specific capital tiers.
- [x] Per-transaction, pending exposure, daily and monthly limits enforced in database triggers.
- [x] Admin exposure and volume summary view.
- [ ] Owner to configure approved capital tier amounts before assigning agents.
- [ ] External documentary evidence upload/storage and manual verification procedure.

### 4. Transaction Tracking
- [x] Unique transaction reference, customer/agent/partner references, country, currency, payment network, amount and evidence reference.
- [x] All required statuses and controlled transition graph.
- [x] Customer tracking-only transaction creation.
- [x] Agent limited progress actions.
- [x] Immutable status history.
- [x] Customer dispute opening and admin resolution workflow.
- [x] 20 requests/hour per authenticated customer anti-abuse throttle.
- [ ] Full browser and adversarial RLS testing.

### 5. Escrow-ready Engine
- [x] Release conditions, future provider code and customer confirmation metadata.
- [x] Dispute metadata.
- [x] Database hard stops: funds_held=false and release_executed=false.
- [ ] Licensed provider integration only after legal/owner approval.
- [ ] No actual escrow or automatic release in V1.

### 6. Agent Commission Engine
- [x] Default 70% agent / 20% MFA company / 10% operations-risk reserve.
- [x] Global/country/service/agent/partner scoped rules.
- [x] Currency-specific rules, effective dates, minimum and maximum commission pool.
- [x] Commission only on completed records assigned to verified agents.
- [x] Historical rule snapshot stored per calculation.
- [x] Immutable non-payable commission entries.
- [ ] Commission reversal/adjustment accounting for post-completion disputes is not implemented; all V1 entries remain non-payable.

### 7. MFA Revenue Engine
- [x] Company, agent and reserve calculation reports.
- [x] Currency, country and partner reporting.
- [x] Revenue summary and agent exposure views.
- [ ] Financial reconciliation against any future licensed provider is out of V1 scope.

### 8. Admin Control Center
- [x] Agent trust and badge management.
- [x] Capital/guarantee review and capital tier configuration.
- [x] Transaction monitoring and assignment.
- [x] Commission configuration.
- [x] Country/currency configuration.
- [x] Partner status management.
- [x] Dispute management.
- [x] Escrow-ready metadata.
- [x] Audit history.
- [ ] Country/regional manager scoped roles remain disabled.

### 9. Security
- [x] RLS on new module tables.
- [x] AAL2 Super Admin write policies.
- [x] Agent/customer/partner data access policies.
- [x] Database input constraints and guarded status transitions.
- [x] Private trigger functions and immutable history/ledger.
- [x] Rate limit for customer tracking record creation.
- [x] Legacy demo service request SECURITY INVOKER/RLS hardening migration.
- [ ] Enable leaked password protection in Supabase Auth.
- [ ] Complete security advisor recheck after staging migrations.
- [ ] Secret scan, dependency advisory triage and adversarial access tests.

### 10. Testing and handover
- [x] Repository audit report.
- [x] Database migrations.
- [x] Frontend and backend trigger/RLS implementation.
- [x] Security report.
- [x] SQL schema smoke-test script.
- [x] Test report with unrun tests clearly identified.
- [x] Backup/recovery runbook.
- [ ] GitHub Actions typecheck/lint/build must pass on final branch head.
- [ ] Apply migrations and run database smoke test on isolated staging.
- [ ] Browser/mobile, concurrency and RLS adversarial tests.
- [ ] Backup/PITR configuration and restore drill.
- [ ] Pull request review and owner approval.

## Migration order

New module migrations are timestamped after the existing agent verification migration:
1. 20261101130000_mfa_agent_trust_capital_commission_tables.sql
2. 20261101131000_mfa_agent_trust_capital_commission_rls.sql
3. 20261101131500_mfa_partner_admin_aal2.sql
4. 20261101132000_mfa_agent_trust_capital_commission_workflows.sql
5. 20261101133000_mfa_public_directory_online_presence.sql
6. 20261101134000_mfa_legacy_demo_request_security_hardening.sql

Before applying them to the live MFA project, reconcile the five missing migration files identified in the repository audit and validate the actual live schema.

## Current status

- Code and SQL migration drafts are committed to feature/agent-trust-capital-commission-v1.
- No migrations were applied to the live Supabase project.
- No real funds, escrow, payment, withdrawal, custody or transfer functionality was activated.
- No changes were made to CFG or any other project.
- CI was running at the time of this report; final status must be confirmed from the latest GitHub Actions run.
- No merge to main or production deployment has been performed.
