# MFA Migration Reconciliation Report V1

**Repository:** `MKONDE/Money-flow-agency`  
**Branch reviewed:** `feature/agent-trust-capital-commission-v1`  
**Supabase project:** `money-flow-agency` (`cabmexujxoosoymsahou`)  
**Review type:** Read-only comparison  
**Date:** 2026-11-09  
**Authorization:** READ-ONLY AUDIT ONLY. No schema changes or migrations authorized/performed.

## Executive summary

The live Supabase migration history contains **13 migration records**. A direct read-only comparison against the named migration files on the reviewed GitHub branch shows:

- **4 exact timestamp/name matches found** in the branch.
- **9 exact files not found** at their corresponding paths on the reviewed branch.
- Two of the missing historical policy-consolidation files have later, differently timestamped consolidation files in the branch. These are potential replacements, not proof of equivalence.
- The missing foundation, send/receive workflow, FK-index, agent-status RPC, public-directory privacy, and agent-review migration history must be reconstructed or otherwise reconciled before any migration is applied.

This report does not claim that missing SQL is safe to recreate from current schema. The live database may contain important historical changes that are not represented in the current branch.

## 1. Live migration history

The Supabase migration API returned these 13 records:

| Live version | Migration name | Exact file on reviewed branch |
|---|---|---|
| 20261031140915 | mfa_foundation_v1 | NOT FOUND |
| 20261031140934 | mfa_security_hardening | FOUND |
| 20261101033516 | mfa_send_receive_requests_v1 | NOT FOUND |
| 20261101033526 | mfa_request_workflow_fk_indexes | NOT FOUND |
| 20261101033713 | mfa_agent_request_status_rpc | NOT FOUND |
| 20261101035716 | mfa_global_representation_country_offices_v1 | FOUND |
| 20261101035950 | mfa_global_presence_aal2_and_column_security | FOUND |
| 20261101092738 | mfa_rls_auth_initplan_optimization | FOUND |
| 20261101100622 | mfa_agent_public_directory_privacy_v1 | NOT FOUND |
| 20261101100653 | mfa_agent_public_directory_materialized_privacy_v1 | NOT FOUND |
| 20261101102303 | mfa_rls_policy_consolidation_global_presence_v1 | NOT FOUND — later variant exists |
| 20261101102331 | mfa_agent_profile_read_policy_consolidation_v1 | NOT FOUND — later variant exists |
| 20261101104628 | mfa_agent_application_review_rpc_v1 | NOT FOUND |

“FOUND” means the exact expected path was retrievable from the reviewed branch. “NOT FOUND” means the exact path was not retrievable at that branch/ref; it does not prove the SQL never existed elsewhere.

## 2. Later variants requiring equivalence review

The reviewed branch contains:

- `20261101103000_mfa_rls_policy_consolidation_global_presence_v1.sql`
- `20261101104500_mfa_agent_profile_read_policy_consolidation_v1.sql`

These appear related by name and purpose to the live versions `20261101102303` and `20261101102331`, respectively. Their timestamps differ. Do not mark the live versions reconciled until the complete SQL bodies, dependencies, grants, policies, and resulting schema effects have been compared.

## 3. Critical gaps and risks

### A. Foundation migration absent by exact path

The live database records `20261031140915_mfa_foundation_v1`, but the matching file was not found on the reviewed branch. This is a critical source-of-truth gap. Recover the original migration from repository history, backups, or another authoritative source. Do not regenerate it from memory or infer it from current tables.

### B. Send/receive workflow migration files absent

The live history records:
- `20261101033516_mfa_send_receive_requests_v1`
- `20261101033526_mfa_request_workflow_fk_indexes`
- `20261101033713_mfa_agent_request_status_rpc`

The exact files were not found on the reviewed branch. These may have created or modified operational request tables, foreign keys, indexes, and RPCs. Recover and compare their original SQL before any replay or reset.

### C. Agent public-directory privacy migrations absent by exact path

The live history records `20261101100622` and `20261101100653`; their exact files were not found. Later branch changes include directory/presence work, but equivalence has not been established. Review public view definitions, materialized view refresh behavior, grants, RLS, contact-consent handling, and exposure of phone/email fields.

### D. Agent application review RPC absent by exact path

The live history records `20261101104628_mfa_agent_application_review_rpc_v1`, but the exact file was not found. The current branch contains a later verification workflow migration (`20261101120000_mfa_agent_verification_workflow.sql`) and related code. Compare the historical RPC signature, authorization checks, role changes, event logging, and transaction_enabled behavior before deciding whether the later implementation supersedes it.

### E. Schema drift remains a release blocker

The existing security report notes operational tables and migration-history differences. This review confirms migration-history/file divergence but does not inspect or certify every live table, constraint, trigger, policy, grant, function, or view. Treat the live database as the authoritative running state until a complete catalog export and comparison is complete.

## 4. Safe reconciliation plan

1. **Freeze migration execution.** Do not apply, replay, squash, reset, or delete migrations on the live MFA project.
2. **Recover originals.** Locate the nine missing SQL files from Git history, other branches, deployment artifacts, backups, or an authoritative migration archive.
3. **Compare exact SQL.** For every live migration, compare original SQL with the current branch and document object-level effects: tables, columns, indexes, constraints, functions, triggers, policies, grants, views, and data updates.
4. **Inspect live catalog read-only.** Export relevant definitions from `pg_catalog` and `information_schema`; compare them against the cumulative expected schema. Include RLS flags and policies, function security mode/search_path/EXECUTE grants, trigger definitions, view security options, and role grants.
5. **Resolve timestamp variants.** Prove whether the two later policy-consolidation migrations are semantically equivalent to their earlier live counterparts. Do not alter migration history solely to make timestamps line up.
6. **Build a clean staging baseline.** Only after recovering authoritative migration sources, construct an isolated MFA staging database and validate the full migration sequence there. Do not use a production clone containing sensitive data unless approved safeguards are in place.
7. **Run tests.** Execute the schema smoke test, role-based RLS tests, AAL2 admin tests, transaction/commission guard tests, and browser/mobile tests on staging.
8. **Prepare a separate change proposal.** Any migration-history repair or new forward-only migration requires a reviewed plan and explicit authorization. Preserve the existing production schema and data.

## 5. Safety invariants to preserve

- MFA remains an independent project and database from CFG.
- MFA does not create or mutate CFG wallet balances or ledger entries.
- Agent float, capital and guarantees remain declarations/documentary references, not money held by MFA.
- Tracking records remain `simulation_only = true`.
- Escrow metadata remains `funds_held = false` and `release_executed = false`.
- Commission records remain `payable = false`.
- No live payment, deposit, withdrawal, custody, escrow release, or payout is activated by this reconciliation.
- No production deployment, merge to main, or database migration is authorized by this report.

## 6. Verification evidence and limitations

- Live migration list was read from Supabase project `money-flow-agency` using the read-only migration-list operation.
- Exact migration file paths were checked on GitHub branch `feature/agent-trust-capital-commission-v1`.
- The branch's PR #2 changed-file list and relevant SQL/test/security documents were inspected.
- No database DDL/DML was executed.
- No live migration was applied.
- No production data was modified.
- This report is a migration-history reconciliation inventory, not a production security sign-off.

## Final status

**RECONCILIATION: INCOMPLETE — BLOCKED ON RECOVERY AND SQL EQUIVALENCE REVIEW.**

The next safe task is to recover the original missing migration SQL and perform a read-only object-level comparison. Do not proceed to live migration execution until that work is complete and separately approved.
