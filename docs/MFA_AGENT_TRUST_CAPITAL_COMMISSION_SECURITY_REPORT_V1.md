# MFA Agent Trust, Capital & Commission Engine V1 — Security Report

**Repository:** https://github.com/MKONDE/Money-flow-agency  
**Branch:** feature/agent-trust-capital-commission-v1  
**Review date:** 2026-11-01  
**Status:** Code and migration draft committed; database/runtime security sign-off pending.

## Executive assessment

The V1 module has been implemented as an additive tracking and governance layer. It does not create a customer wallet, token, stored-value balance, custody account, payment processor, escrow balance or payout path. Database constraints hard-block the three critical switches: transaction records must be simulation-only, escrow records cannot mark funds held or released, and commission entries cannot become payable.

This is not a production security approval. The migrations have not been applied to a staging database, and no end-to-end RLS or adversarial tests have been executed.

## Implemented controls

### Identity and role boundaries
- Admin route checks authenticated profiles.role = super_admin and Supabase AAL2.
- Admin write RLS policies require both private.current_mfa_role() = super_admin and JWT AAL2.
- Agents can edit only their own declared capital/float fields, submit documentary guarantee references and progress their own assigned tracking requests through permitted statuses.
- Customers can create and read only their own tracking records and open permitted disputes.
- Partner owners receive read-only visibility of transaction records referencing their own partner record.
- Country and regional manager write access remains disabled.

### Agent trust
- Trust levels: Independent, Verified, Capital-Backed, Premium and Strategic.
- Trust changes are recorded in an append-only history table and financial audit trail.
- Higher levels require an already verified agent profile.
- Capital-Backed additionally requires a positive capital declaration and a separately verified, in-date guarantee reference.
- Public trust badges are shown only for active, unexpired badges belonging to verified agents.

### Capital and guarantees
- Declared capital and declared transaction float are stored separately.
- Guarantee issuer/reference/amount/currency/validity/evidence references are stored separately from capital declarations.
- Agent-submitted guarantees begin as pending; only AAL2 Super Admin can verify or reject them.
- MFA does not collect guarantee money, bank deposits or original bank account credentials.
- Admin-configured capital tiers are currency-specific. No invented monetary tier thresholds are seeded.
- Agent assignment checks declared capital, verified guarantee amount, per-transaction cap, pending exposure, daily volume and monthly volume.
- An assignment advisory lock serializes per-agent limit checks to reduce concurrent over-assignment.

### Transaction and dispute controls
- Transaction references are unique and include customer, agent and partner references, country, currency, payment network, amount, evidence reference and status.
- All customer-created records are constrained to simulation_only = true.
- Status transitions are validated in a private trigger; status history is append-only.
- Customers may open disputes only after payment evidence has been submitted and the request has entered a review/confirmation stage.
- Dispute events are append-only and status changes are audited.
- Authenticated customers are throttled to 20 tracking requests per hour per user ID. This is an initial anti-abuse guardrail, not a business transaction limit.

### Escrow-ready metadata
- The table stores release conditions, future licensed-provider code, dispute state and customer confirmation.
- No amount, escrow balance or payment destination exists in the workflow table.
- Database checks require funds_held = false and release_executed = false.
- Customer confirmation closes the metadata workflow only; it never releases funds.

### Commission and revenue
- Commission is calculated only when an assigned agent is verified and the tracking record reaches COMPLETED.
- The commission base is the explicit commissionable_amount service-fee pool; the transaction principal is not automatically treated as commission.
- Default allocation: Agent 70%, MFA Company 20%, Operations & Risk Reserve 10%.
- Scope precedence: agent, partner, service, country, global; currency-specific rules take priority within a scope.
- Effective dates, minimum/maximum commission pool and the exact rule snapshot are retained.
- Commission entries are append-only and constrained to payable = false; no payout or withdrawal route exists.

### Audit and access control
- RLS is enabled on all new public-schema tables.
- Trust history, transaction status history, dispute events, commission entries and financial audit events are append-only.
- Trigger functions are in the non-exposed private schema and have API-role EXECUTE privileges revoked.
- Legacy demo service-request hardening revokes anon access, narrows agent updates and converts the agent RPC to SECURITY INVOKER with RLS-backed checks.

## Live Supabase observations (read-only inspection)

The connected project is named money-flow-agency, separate from CFG. No DDL or migration was applied during this review.

The live migration history contains 12 entries, including these versions that are not currently represented by migration files in this repository:
- 20261101033516 mfa_send_receive_requests_v1
- 20261101033526 mfa_request_workflow_fk_indexes
- 20261101033713 mfa_agent_request_status_rpc
- 20261101102303 mfa_rls_policy_consolidation_global_presence_v1
- 20261101102331 mfa_agent_profile_read_policy_consolidation_v1

The live database also contains operational tables not fully represented by the checked-in migration history, including partner services, payment partners, agent service listings, partner confirmations, receipts, service disputes, service requests and service-request events. This is schema drift. Do not apply the complete repository migration folder blindly to the live database until the missing migration history has been reconciled.

### Existing Supabase Security Advisor findings

1. Authenticated SECURITY DEFINER function: the live database reports public.agent_update_service_request(uuid,text,text) as executable by authenticated users while SECURITY DEFINER. The inspected function does verify a signed-in verified agent, assigned request, demo-only flag and allowed status transitions; the warning is not by itself proof of an exploit. The new migration 20261101134000_mfa_legacy_demo_request_security_hardening.sql changes it to SECURITY INVOKER and adds RLS/trigger enforcement, and revokes anon privileges. This fix is committed but not yet applied to the live database.
2. Leaked password protection disabled: Supabase Auth currently reports this protection as disabled. Enable it in the MFA Supabase Auth password-security settings before production. This is a dashboard-level setting and is not changed by SQL migrations.

The live database also had broad anon table grants on legacy demo service-request tables despite RLS being enabled. The new hardening migration revokes those grants; this has not yet been applied.

## Remaining security gates

- Apply migrations to an isolated MFA staging database after schema reconciliation.
- Execute the SQL smoke tests and full role/RLS tests with customer, agent, partner and Super Admin test accounts.
- Verify that non-AAL2 admins cannot change guarantees, tiers, badges, partners, transactions, disputes or commission rules.
- Run concurrent transaction-assignment tests against capital limits and verify the advisory lock behavior.
- Verify the 20-per-hour request throttle.
- Enable leaked-password protection and verify email/MFA settings in Supabase Auth.
- Configure and test backups/restore before any production release.
- Complete mobile/browser accessibility and responsive testing.
- Complete dependency advisory review and secret scanning.
- Obtain legal/compliance review before enabling any regulated financial activity.

## Explicitly not implemented

- No real deposits, withdrawals, payment execution, custody, escrow holding/release, crypto, tokens, wallets or payouts.
- No external licensed escrow provider integration.
- No partner API credentials or signed webhooks.
- No Storage upload bucket for agent logos or guarantee documents; only safe reference strings are stored.
- No production deployment or merge to main.
