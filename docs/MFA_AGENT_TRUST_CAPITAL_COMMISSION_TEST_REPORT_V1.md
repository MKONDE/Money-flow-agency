# MFA Agent Trust, Capital & Commission Engine V1 — Test Report

**Branch:** feature/agent-trust-capital-commission-v1  
**Date:** 2026-11-01  
**Result:** Implementation committed; runtime verification pending.

## Automated checks

| Check | Status | Evidence |
|---|---|---|
| TypeScript typecheck | Passed | GitHub Actions run 41298355742, commit 8dcf615 |
| ESLint | Passed | GitHub Actions run 41298355742, commit 8dcf615 |
| Production build | Passed | GitHub Actions run 41298355742, commit 8dcf615 |
| SQL safety grep checks | Passed | GitHub Actions run 41298355742, commit 8dcf615 |
| Database schema smoke test | Not run | Requires the new migrations on an isolated MFA test database |
| Browser/mobile end-to-end tests | Not run | Requires configured test Supabase users and browser QA |
| RLS adversarial tests | Not run | Requires customer, agent, partner and AAL2 admin test identities |
| Backup restore test | Not run | Requires configured Supabase backup/PITR and isolated restore target |

## Test coverage prepared

1. Agent registration and directory: register individual/business agent; verify country, city, service and supported payment networks; verify online/offline sync; verify phone/email hidden until explicit public consent; search by country, city and business name.
2. Verification and trust: pending agent cannot receive a higher trust level; verified agent can receive approved higher trust classifications; Capital-Backed requires declared capital and a separately verified in-date guarantee; badge suspension/revocation removes public badge visibility; trust history and audit rows cannot be updated or deleted.
3. Capital tiers and limits: missing declaration, currency mismatch, missing verified guarantee or unmatched tier prevents assignment; per-transaction, pending-exposure, daily and monthly caps reject over-limit assignments; concurrent assignments are serialized per agent; declared float is not money held by MFA.
4. Transactions: customer can create only a CREATED, unassigned, simulation-only record; customer cannot assign an agent, set commissionable amount or change status; agent can advance only PENDING_AGENT → PAYMENT_PENDING → PAYMENT_SUBMITTED; non-verified or unassigned agent cannot progress; Super Admin transitions follow the state graph; each status change creates immutable history; creation is throttled at 20 per hour per user.
5. Commission: non-verified agents and non-COMPLETED records do not accrue entries; commissionable amount is explicit and cannot exceed transaction amount; default 70/20/10 shares sum to the commission pool subject to recorded rounding remainder; specific rules override broader rules; historical snapshots remain unchanged; entries cannot be updated, deleted or made payable.
6. Disputes and escrow-ready metadata: disputes open only after evidence submission; opening a dispute moves the tracking record to DISPUTED; dispute events are immutable; customer confirmation is available only after admin preparation; database rejects funds_held=true and release_executed=true.
7. Security and responsiveness: anon cannot access private tracking/capital/guarantee records; customer cannot access another customer's records; agent cannot access another agent's records or edit financial metadata; partner owner is restricted to its own partner reference; admin writes fail without Super Admin role and AAL2; test desktop/mobile, keyboard navigation and accessible labels.

## Database smoke test

Run supabase/tests/mfa_agent_trust_capital_commission_v1.sql only after applying all required migrations to the dedicated MFA test/staging database. The script checks required tables, RLS enablement, default 70/20/10 rule, tracking-only constraints, escrow hard stops, non-payable commission guard, history triggers, commission trigger and revenue view.

The smoke test is a schema-presence check. It does not replace the role-based integration tests listed above.

## Current result

Typecheck, lint, production build and SQL safety checks passed on commit 8dcf615. Later changes to SQL migrations and documentation are being checked by the latest branch workflow; the latest branch-head run has not yet completed. No migrations were applied to the connected live MFA database. No real payment, deposit, withdrawal, transfer, escrow, custody or payout was performed. The branch must not be treated as production-ready until staging database, RLS, concurrency, browser/mobile and recovery tests pass.
