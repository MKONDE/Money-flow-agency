# MFA Repository Audit — Agent Trust, Capital & Commission Engine V1

**Repository:** MKONDE/Money-flow-agency  
**Base branch:** main  
**Module branch:** feature/agent-trust-capital-commission-v1  
**Parent development branch:** feature/mfa-foundation-audit-v1  
**Review date:** 2026-11-01

## Executive summary

The repository already contained a Next.js 16 + TypeScript + Supabase foundation, agent registration, a verified-agent public directory, an agent portal, a Super Admin portal, global representation/location features and an initial demo service-request workflow.

The Agent Trust, Capital & Commission Engine was only partially present before this task. Registration, verification and a basic directory existed; capital declarations, verified guarantees, capital tiers, dedicated tracking transactions, escrow-ready metadata, commission rules/ledger and revenue reporting did not exist as a complete module.

The new feature branch adds these capabilities without modifying main or any CFG repository/database. The module is a tracking and accounting-calculation layer only. It cannot hold funds, execute payments, release escrow or pay commissions.

## Repository and branch

- Repository: MKONDE/Money-flow-agency (private).
- Default branch: main.
- New branch created: feature/agent-trust-capital-commission-v1.
- New branch was based on the previously reviewed development branch, feature/mfa-foundation-audit-v1, so existing foundation work is preserved.
- No direct main commit.
- No merge and no production deployment.
- No .env file or secret was added.

## Existing functionality found

- Agent account/application registration and pending verification.
- Agent profile fields for business identity, country, region, city, services, languages and payment networks.
- Verified-only public agent directory projection.
- Agent online/offline state.
- Super Admin route protected by profile role and AAL2.
- Agent application approve/reject/suspend/request-information workflow.
- Country representation and location profiles.
- Existing demo service-request workflow and agent assignment.
- Supabase Auth SSR and RLS foundations.

## New implementation on this branch

### Database migrations
1. 20261101130000_mfa_agent_trust_capital_commission_tables.sql
2. 20261101131000_mfa_agent_trust_capital_commission_rls.sql
3. 20261101131500_mfa_partner_admin_aal2.sql
4. 20261101132000_mfa_agent_trust_capital_commission_workflows.sql
5. 20261101133000_mfa_public_directory_online_presence.sql
6. 20261101134000_mfa_legacy_demo_request_security_hardening.sql

### Frontend/backend
- Agent capital and transaction-float declaration form.
- Separate documentary guarantee reference submission and admin verification.
- Trust classifications, badge suspension/revocation and history.
- Currency-specific capital tier configuration.
- Transaction tracking records, allowed status transitions and immutable history.
- Customer tracking page, agent tracking queue and dispute form.
- Escrow-ready metadata with customer confirmation; no fund release.
- Commission rules with global/country/service/agent/partner scope, effective dates and caps/minimums.
- Default 70/20/10 commission calculation snapshot.
- Non-payable commission ledger and revenue/country/partner reports.
- Agent pending exposure, daily and monthly volume reporting.
- Public directory filters, online status, payment network display and opt-in public contact consent.
- Admin AAL2 control center and links from the main admin workspace.
- 20 tracking-request creations per hour per authenticated customer as an initial rate guardrail.
- Legacy demo service-request RLS/ACL hardening and SECURITY INVOKER agent RPC.
- SQL schema smoke test, security report, test report and backup/recovery runbook.

## Critical financial safety constraints

- Every MFA tracking transaction must have simulation_only = true.
- Escrow workflows must have funds_held = false and release_executed = false.
- Commission entries must have payable = false.
- Commission is calculated on the explicit commissionable_amount service-fee pool, not automatically on transaction principal.
- No customer wallet, MFA token, stored-value balance, real deposit, withdrawal, custody, payment execution, escrow balance or payout path is created.
- Capital float and guarantee data are declarations/references only.
- CFG remains a separate partner; no CFG database, wallet or ledger connection is introduced.

## Live Supabase schema audit

The connected project is named money-flow-agency and is separate from CFG. Only read-only catalog, migration-history and advisor queries were run. No new module migration was applied.

The live migration history contains 12 versions. Five live migration versions are absent from the repository migration folder:
- 20261101033516 — mfa_send_receive_requests_v1
- 20261101033526 — mfa_request_workflow_fk_indexes
- 20261101033713 — mfa_agent_request_status_rpc
- 20261101102303 — mfa_rls_policy_consolidation_global_presence_v1
- 20261101102331 — mfa_agent_profile_read_policy_consolidation_v1

The live database also contains operational tables (service requests/events, partner services, payment partners, agent service listings, partner confirmations, receipts and service disputes) that are not fully represented by checked-in migrations. This is migration-history/schema drift. Reconcile the missing migration files before replaying the entire repository migration folder against any shared/live database. The new 20261101134000 hardening migration safely skips the optional legacy service-request tables if they are absent.

## Security observations

Supabase Security Advisor reported:
1. A SECURITY DEFINER public.agent_update_service_request function executable by authenticated users. Its inspected implementation checks verified-agent identity, assigned request, demo_only and allowed transitions, but the advisor flags its execution mode. This branch includes a migration to convert it to SECURITY INVOKER, add an assigned-agent RLS update policy and private trigger validation, and revoke anon table privileges. The fix is not yet applied to the live database.
2. Leaked password protection is disabled in Supabase Auth. This must be enabled in the Supabase dashboard before production.

The live database had anon grants on legacy demo service-request tables even though RLS was enabled. The new migration revokes those grants; not yet applied.

## Validation status

- GitHub Actions: runs on all feature branches; latest run is in progress at the time of this report.
- SQL smoke test: committed, not run against a migrated staging database.
- Supabase live DDL: not applied.
- Browser/mobile QA: pending.
- RLS adversarial tests and concurrent limit tests: pending.
- Backup configuration and restore drill: pending.
- Dependency audit previously reported 16 moderate vulnerabilities; advisory triage remains required.

## Remaining production gates

- Reconcile live migration history with repository migrations.
- Apply migrations to isolated MFA staging and run SQL smoke tests.
- Run role/RLS, concurrency, commission snapshot, dispute and mobile browser tests.
- Enable leaked-password protection.
- Configure backup/PITR and complete restore drill.
- Complete logo/profile image storage upload and partner API/webhook work.
- Obtain legal/compliance approval for any future regulated activity.
- Owner approval for merge and any production deployment.

## Conclusion

The module is implemented in the feature branch at code and migration-draft level. It is not yet live, runtime-validated or production-ready. No money movement or CFG integration has been enabled.
