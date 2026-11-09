# MFA Least-Privilege Remediation Plan V1

**Repository:** `MKONDE/Money-flow-agency`  
**Branch:** `feature/agent-trust-capital-commission-v1`  
**Related PR:** #2 — Draft / unmerged  
**Supabase project:** `money-flow-agency` (`cabmexujxoosoymsahou`)  
**Plan date:** 2026-11-09  
**Status:** PROPOSAL ONLY — NO GRANT, POLICY, AUTH, OR DATABASE CHANGES AUTHORIZED

## 1. Purpose and safety boundary

This document converts the read-only catalog findings in `MFA_MIGRATION_RECONCILIATION_REPORT_V1.md` into a table-by-table least-privilege review plan.

It is not an executable migration and must not be applied to the live database. It does not authorize revoking grants, changing default privileges, editing RLS policies, changing function security, changing Supabase Auth settings, deploying, or merging.

MFA remains an independent project and database. CFG alone remains authoritative for CFG settlement, balances, and ledger entries. MFA capital/float/guarantee values remain declarations or documentary references. Tracking transactions remain simulation-only; escrow metadata remains non-custodial; commission snapshots remain non-payable.

## 2. Evidence baseline from the read-only audit

The live catalog showed 19 public application tables, with RLS enabled on all 19. The grouped grant inventory reported:

- `anon`: SELECT on 12 tables; INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, and TRIGGER on 14 tables.
- `authenticated`: SELECT on 17 tables; INSERT, DELETE, TRUNCATE, REFERENCES, and TRIGGER on 19 tables; UPDATE on 17 tables.
- `service_role`: common table privileges on all 19 tables.
- Public-schema default ACL entries include API roles for future tables, sequences, and functions. Grantor/owner provenance is not yet resolved.
- `public_agent_directory` currently exposes a limited projection (id, brand_name, description, country_code, region, city, services, languages, logo_url, synced_at); no phone, email, or street address columns were observed.
- `country_offices` and `country_representatives` have public-read policies but the inspected grant inventory did not show anon/authenticated SELECT grants. Intended API visibility must be confirmed.
- RLS does not neutralize TRUNCATE. Broad table grants are therefore a priority even where row-level write policies appear restrictive.

This is catalog evidence, not proof that every listed operation is exploitable. Validate grants, policies, function execution paths, ownership, and actual API behavior together.

## 3. Proposed target access matrix

Legend:
- **No direct grant** = default target; use a narrowly scoped RPC/Edge Function only where a documented use case requires it.
- **SELECT (public projection)** = read only the explicitly approved public fields, not underlying private profile or application records.
- **Owner-scoped** = only the authenticated record owner, enforced by RLS and immutable ownership checks.
- **Admin-scoped** = only authorized MFA administrators; sensitive actions additionally require AAL2.
- **Backend-only** = server-side service role or a narrowly scoped privileged function; never expose service-role credentials to a browser/mobile client.
- **Conditional** = confirm product/API requirements before granting anything.

| Public table | anon target | authenticated target | service_role target | Required validation |
|---|---|---|---|---|
| `agent_location_profiles` | No direct grant | Owner-scoped read/write; admin-scoped review | Backend-only | Owner cannot change agent identity, approval, or admin-controlled fields |
| `agent_profiles` | No direct grant | Owner-scoped limited read/update; admin-scoped review | Backend-only | Public profile fields must flow only through the directory projection; protect verification/status/role fields |
| `agent_service_listings` | No direct grant by default; public published listing access only if explicitly approved | Owner-scoped create/update of own eligible listings; admin-scoped moderation | Backend-only | Unverified agents cannot publish; owner cannot set approval/published/admin fields |
| `agent_verification_events` | No direct grant | Admin-scoped read; agent may receive only a deliberately limited own-status view via safe RPC if required | Backend-only | Append-only audit; clients cannot insert/update/delete |
| `audit_logs` | No direct grant | Admin-scoped read only where necessary | Backend-only | Append-only; no client write path |
| `business_partners` | No direct grant | Conditional limited read; admin-scoped management | Backend-only | Confirm whether partner catalog is intended to be public; do not expose private partner data |
| `country_offices` | Conditional SELECT only if public directory is intended | Conditional SELECT; admin-scoped management | Backend-only | Resolve current policy/grant mismatch; define public columns and avoid broad table exposure |
| `country_representatives` | Conditional SELECT only if public directory is intended | Conditional SELECT; admin-scoped management | Backend-only | Resolve current policy/grant mismatch; define public columns and avoid private contact exposure |
| `global_presence_audit_log` | No direct grant | Admin-scoped read only | Backend-only | Append-only; AAL2 for privileged review; no client writes |
| `partner_confirmations` | No direct grant | Participant-scoped read; narrow participant action only if workflow requires it | Backend-only | User A cannot access user B's confirmation; protect partner/admin decision fields |
| `partner_services` | No direct grant by default; public published catalog only if approved | Conditional limited read; admin/partner-scoped management | Backend-only | Confirm publication and partner ownership rules |
| `payment_partners` | No direct grant by default; only safe public provider metadata if approved | Conditional limited read; admin-scoped management | Backend-only | Never expose credentials, private integration configuration, or operational secrets |
| `profiles` | No direct grant | Owner-scoped read/update of safe fields; admin-scoped role review | Backend-only | Role, privilege, and verification fields must not be user-editable |
| `public_agent_directory` | SELECT on approved public projection only | SELECT on approved public projection only | Backend-only maintenance | Keep current data-minimized projection; no phone/email/street address without explicit consent and review |
| `receipt_records` | No direct grant | Participant-scoped read; narrowly scoped submission through controlled path if required | Backend-only | Receipt ownership, file access, status and verification cannot be forged |
| `service_disputes` | No direct grant | Dispute participant-scoped read; controlled participant submission/update fields only | Backend-only | No cross-user access; preserve immutable decision/audit fields |
| `service_request_events` | No direct grant | Participant-scoped read only; no direct client mutation | Backend-only | Append-only event history; prevent event spoofing |
| `service_requests` | No direct grant | Requester/assigned-agent scoped read; narrow workflow actions through validated RPC | Backend-only | Enforce assignment, verification, allowed transitions and immutable requester/agent IDs |
| `support_tickets` | No direct grant | Owner-scoped create/read and limited follow-up; admin-scoped support operations | Backend-only | User A cannot read/update user B's ticket; protect staff-only notes and status decisions |

**Important:** This matrix is a proposed target, not a declaration that the current application supports every row exactly as written. Where product behavior is unclear, keep the decision conditional and inspect the UI/API call sites before changing grants.

## 4. Global privilege rules to evaluate

1. Remove `TRUNCATE`, `REFERENCES`, and `TRIGGER` from `anon` and `authenticated` unless a documented, tested application requirement proves otherwise. RLS does not row-filter TRUNCATE.
2. Default to no direct table writes for audit/event/verification tables. Use server-controlled append paths.
3. Grant only the minimum required table operation. Do not grant all CRUD privileges as a bundle.
4. For public data, prefer a narrow public projection or carefully scoped RPC over exposing a sensitive base table.
5. Preserve RLS as a second authorization layer; table grants and RLS must both express the intended access.
6. Keep `service_role` strictly server-side. Never put its key in frontend code, mobile bundles, logs, public environment variables, or user-visible configuration.
7. Review function EXECUTE grants independently. A table grant matrix does not secure callable SECURITY DEFINER RPCs.
8. Trace object owner and grantor provenance before changing default privileges. Default ACL changes must be scoped to the correct object-creating roles and schema.
9. Do not drop unused indexes based only on Performance Advisor warnings.
10. Consolidate permissive RLS policies only after proving identical authorization semantics; permissive policies combine using OR semantics.

## 5. Staged validation plan

### Stage A — application dependency inventory (read-only)
- Search frontend, server, Edge Function, and test code for direct reads/writes to all 19 tables.
- Record each operation, caller role, required columns, and whether a server-side path already exists.
- Identify public pages that consume country office/representative, partner, payment partner, or service listing data.
- Trace every RPC call and its EXECUTE grants.
- Resolve object owner/grantor for existing and default ACL entries.

Exit criterion: every current table operation has a named feature, caller role, and justification.

### Stage B — draft grant diff (not applied)
- Prepare a proposed SQL diff in a separate review artifact.
- Include explicit revoke/grant statements only after Stage A.
- Scope default-privilege changes by schema and object owner.
- Preserve required public directory reads and all legitimate owner/admin workflows.
- Include rollback notes and expected API behavior changes.

Exit criterion: peer-reviewed grant diff with no unexplained privilege and no production execution.

### Stage C — isolated staging tests
Run tests with real `anon`, `authenticated`, and privileged backend contexts:
- Anonymous read attempts against profiles, applications, audit logs, partner confirmations, receipts, disputes, requests, events, and support tickets.
- Anonymous public-directory reads limited to approved columns.
- Authenticated user A attempts to read and mutate user B's records.
- Unverified agent attempts to publish listings or update assigned requests.
- Verified agent attempts to alter another agent's request or event.
- Non-admin and AAL1 admin attempts to perform AAL2/admin-only operations.
- Direct SQL/API attempts for INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, and TRIGGER where applicable.
- Attempts to change owner IDs, agent assignment, verification status, admin roles, review decisions, commission state, and immutable audit fields.
- Public country-office/representative access tests after intended visibility is confirmed.
- Verify all MFA transaction rows remain simulation-only; escrow remains not held/not released; commissions remain non-payable.

Exit criterion: positive tests for intended operations and negative tests for all forbidden operations, with logs and test evidence.

### Stage D — release gate
Before any production remediation:
- Recover and reconcile missing historical migration sources as required by the migration report.
- Review both authenticated-callable SECURITY DEFINER RPCs and their EXECUTE grants.
- Enable leaked-password protection in MFA Auth after explicit operator approval.
- Complete staging schema smoke tests, RLS adversarial tests, browser/mobile tests, concurrency tests, and backup/restore drill.
- Verify current branch CI on the exact head SHA.
- Obtain separate explicit approval for each production grant/default-ACL/RPC/Auth change.
- Do not merge PR #2 or deploy as part of this plan.

## 6. Priority order

| Priority | Item | Why |
|---|---|---|
| P0 | Trace default ACL owner/grantor and broad anon/authenticated grants | Future objects may inherit excessive permissions; TRUNCATE is not filtered by RLS |
| P0 | Inventory application call sites for all 19 tables | Avoid breaking legitimate features when narrowing grants |
| P1 | Resolve country office/representative policy-grant mismatch | Intended public API behavior is unclear |
| P1 | Review callable SECURITY DEFINER RPCs | Privileged function execution needs a defensible boundary |
| P1 | Stage adversarial role/RLS tests | Static policy inspection is not sufficient |
| P1 | Enable leaked-password protection before production | Existing Auth security warning |
| P2 | Review permissive-policy duplication and unused indexes | Performance/maintainability; no blind edits |

## 7. Explicit non-actions

This plan does **not**:
- revoke or grant any privilege;
- alter default privileges;
- alter RLS policies or functions;
- execute migrations or SQL against Supabase;
- change Auth configuration;
- access or modify user business records;
- enable payments, deposits, withdrawals, custody, escrow release, or payouts;
- merge PR #2, close PRs, or deploy.

## Final status

**LEAST-PRIVILEGE PLAN: DRAFTED FOR REVIEW — IMPLEMENTATION NOT AUTHORIZED.**

The next safe action is to inventory application call sites and trace default ACL grantors/owners, then prepare a separate staging-only grant diff. Production changes remain blocked pending explicit approval.
