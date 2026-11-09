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

## 7. Read-only live schema and security catalog inspection (2026-11-09)

A further read-only catalog inspection was performed against the live MFA project. The queries inspected relation metadata, public-schema RLS/policy counts, selected RPC definitions and ACLs, public triggers, table grants, and Supabase Security Advisor findings. No DDL or DML was run.

### A. Public application tables and RLS

The live catalog returned **19 public application tables**. RLS is enabled on all 19. RLS is not forced on these tables. The live catalog reported these policy counts:

| Table | RLS | Policies |
|---|---:|---:|
| agent_location_profiles | enabled | 4 |
| agent_profiles | enabled | 2 |
| agent_service_listings | enabled | 4 |
| agent_verification_events | enabled | 2 |
| audit_logs | enabled | 1 |
| business_partners | enabled | 1 |
| country_offices | enabled | 4 |
| country_representatives | enabled | 4 |
| global_presence_audit_log | enabled | 2 |
| partner_confirmations | enabled | 2 |
| partner_services | enabled | 2 |
| payment_partners | enabled | 2 |
| profiles | enabled | 2 |
| public_agent_directory | enabled | 1 |
| receipt_records | enabled | 2 |
| service_disputes | enabled | 3 |
| service_request_events | enabled | 4 |
| service_requests | enabled | 3 |
| support_tickets | enabled | 3 |

This is a positive baseline, not proof that the policies are correct. Policy expressions and negative/cross-user access cases still require adversarial role-based testing. RLS not being forced also means table-owner/service contexts need separate review; do not infer a vulnerability solely from relforcerowsecurity = false.

### B. Security Advisor findings — release blockers

The live Supabase Security Advisor returned three warning instances across two finding categories:

1. **public.agent_update_service_request(uuid, text, text) — authenticated SECURITY DEFINER RPC.** It is callable by authenticated. Its current definition uses SECURITY DEFINER, an empty search_path, checks that the caller has a verified agent profile, locks the assigned demo request, validates allowed status transitions, and writes a service-request event. These checks are useful, but the advisor correctly flags the privileged callable surface. Compare the live definition to the branch's intended SECURITY INVOKER hardening migration; do not change the live function during this audit.
2. **public.mfa_review_agent_application(uuid, text, text, text) — authenticated SECURITY DEFINER RPC.** It is callable by authenticated. Its current definition explicitly checks auth.uid(), requires JWT AAL2, checks profiles.role = super_admin, validates review actions and reasons, locks the application row, updates status with transaction_enabled = false, and writes a verification event. Despite those internal checks, the advisor flags the callable SECURITY DEFINER function. Review whether this privileged RPC should remain SECURITY DEFINER, be moved to a non-exposed schema, or be replaced with an appropriately secured invoker design. Any change requires SQL review and separate authorization.
3. **Supabase Auth leaked-password protection is disabled.** Enablement is a production security prerequisite, but this report did not change Auth settings.

Advisor remediation references:
- [Authenticated SECURITY DEFINER function executable](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable)
- [Leaked password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection)

### C. Public triggers

The catalog returned seven trigger event rows across six trigger names:
- agent_location_profiles_updated_at — BEFORE UPDATE
- agent_profiles_set_updated_at — BEFORE UPDATE
- sync_public_agent_directory_trigger — AFTER INSERT and AFTER UPDATE on agent_profiles
- country_offices_updated_at — BEFORE UPDATE
- country_representatives_updated_at — BEFORE UPDATE
- profiles_set_updated_at — BEFORE UPDATE

Trigger function bodies and their execution privileges were not fully audited in this pass. The public-directory synchronization trigger should be included in the privacy/data-minimization review.

### D. Grants require a table-by-table review

The information-schema grant inventory shows anon and/or authenticated table privileges on several public tables, including broad privilege sets on some tables. RLS policies are therefore an essential row-level boundary, but grants and policies must be evaluated together. Some tables have no SELECT grant for anon; others have multiple DML privileges listed. Before production, prepare an explicit least-privilege matrix for anon, authenticated, and service_role, then compare each grant with its intended API exposure and RLS policy. Do not revoke grants blindly as part of this report.

### E. Interpretation

- Positive: all 19 public application tables in the catalog inventory had RLS enabled.
- Not yet certified: policy correctness, table-level least privilege, trigger safety, view/materialized-view security, storage bucket policies, and cross-user isolation.
- Confirmed security warnings: two authenticated-callable SECURITY DEFINER RPCs and leaked-password protection disabled.
- The migration-source gap remains unresolved. Live catalog state must not be used as a substitute for recovering the original migration SQL.

## 8. Updated release gate

**MFA remains NOT READY for production.** Before any production release, the project still needs: migration-source recovery and object-level reconciliation; RPC privilege/security review; leaked-password protection enabled; least-privilege grants review; adversarial RLS tests; trigger/view/storage review; staging smoke tests; and browser/mobile verification.

This additional inspection was read-only. No schema, data, Auth configuration, migration history, payment flow, or deployment state was changed.

## 9. Grant inventory detail — follow-up finding (2026-11-09)

A grouped read-only query against `information_schema.role_table_grants` identified the following privilege footprint across the 19 public application tables:

| Role | Privilege | Number of tables |
|---|---|---:|
| anon | SELECT | 12 |
| anon | INSERT | 14 |
| anon | UPDATE | 14 |
| anon | DELETE | 14 |
| anon | TRUNCATE | 14 |
| anon | REFERENCES | 14 |
| anon | TRIGGER | 14 |
| authenticated | SELECT | 17 |
| authenticated | INSERT | 19 |
| authenticated | UPDATE | 17 |
| authenticated | DELETE | 19 |
| authenticated | TRUNCATE | 19 |
| authenticated | REFERENCES | 19 |
| authenticated | TRIGGER | 19 |
| service_role | SELECT/INSERT/UPDATE/DELETE/TRUNCATE/REFERENCES/TRIGGER | 19 each |

This is a **high-priority least-privilege review item**. RLS does not replace table-level grants: RLS filters rows for applicable roles, while grants determine which SQL operations a role may attempt. In particular, broad INSERT/UPDATE/DELETE/TRUNCATE/REFERENCES/TRIGGER grants to `anon` and `authenticated` should not be accepted without an explicit, table-by-table justification. This inventory alone does not prove that unauthorized data can be changed, because RLS policies, function paths, ownership, and execution context also matter. It does establish that the grant surface is broader than a minimal public-client design would normally require.

**Required next action:** create a least-privilege matrix for every public table and each API role; validate expected public reads, authenticated owner operations, admin-only actions, and service-role backend access. Then test the matrix using real anon/authenticated role contexts on isolated staging. Any grant revocation or policy change must be proposed separately, reviewed against application behavior, and explicitly authorized. No grants were changed during this audit.

## 10. Catalog inventory totals and limitations

The read-only catalog returned **57 public-schema indexes, 85 constraints (including 28 foreign keys)**, and no ordinary views in `pg_views`. This does not rule out materialized views or objects in non-public schemas; those were not exhaustively certified in this pass. The public table column inventory was retrieved, but the full column-by-column output is intentionally not duplicated in this report.

No table data was selected. No schema, grants, policies, functions, triggers, Auth settings, migration history, or deployment state was changed.
