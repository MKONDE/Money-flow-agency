# MFA Migration History Reconciliation V1

**Repository:** `MKONDE/Money-flow-agency`  
**Branch:** `feature/agent-trust-capital-commission-v1`  
**Supabase project:** `money-flow-agency` (`cabmexujxoosoymsahou`)  
**Scope:** Read-only comparison of live migration history and branch migration directory  
**Status:** Reconciliation findings recorded; no migration applied and no database state changed.

## 1. Executive summary

The live Supabase migration history contains **13 applied migration records**. The feature branch contains **18 SQL migration files** in `supabase/migrations`.

A filename/version comparison shows:
- **4 exact timestamp-version matches** between live history and branch filenames.
- **9 live migration records do not have an exact same-version filename** in the branch.
- Several branch files have plausible related names or nearby timestamps, but this is not proof that their SQL is semantically equivalent to the applied live migration.
- The branch also contains later migration files that are not represented in the live applied-history list.

**Important:** A filename mismatch is migration drift evidence, not proof that the live database is wrong. Do not rename, delete, re-baseline, repair migration history, or apply a replacement migration until the original SQL and schema effects are recovered and compared.

## 2. Live migration history (13 records)

| Live version | Live migration name |
|---|---|
| 20261031140915 | mfa_foundation_v1 |
| 20261031140934 | mfa_security_hardening |
| 20261101033516 | mfa_send_receive_requests_v1 |
| 20261101033526 | mfa_request_workflow_fk_indexes |
| 20261101033713 | mfa_agent_request_status_rpc |
| 20261101035716 | mfa_global_representation_country_offices_v1 |
| 20261101035950 | mfa_global_presence_aal2_and_column_security |
| 20261101092738 | mfa_rls_auth_initplan_optimization |
| 20261101100622 | mfa_agent_public_directory_privacy_v1 |
| 20261101100653 | mfa_agent_public_directory_materialized_privacy_v1 |
| 20261101102303 | mfa_rls_policy_consolidation_global_presence_v1 |
| 20261101102331 | mfa_agent_profile_read_policy_consolidation_v1 |
| 20261101104628 | mfa_agent_application_review_rpc_v1 |

## 3. Branch migration files (18 files)

The branch currently contains:

1. `202610310001_mfa_foundation.sql`
2. `20261031140934_mfa_security_hardening.sql`
3. `20261101035716_mfa_global_representation_country_offices_v1.sql`
4. `20261101035950_mfa_global_presence_aal2_and_column_security.sql`
5. `20261101092738_mfa_rls_auth_initplan_optimization.sql`
6. `20261101100600_mfa_agent_public_directory_privacy_v1.sql`
7. `20261101100700_mfa_agent_public_directory_materialized_privacy_v1.sql`
8. `20261101103000_mfa_rls_policy_consolidation_global_presence_v1.sql`
9. `20261101104500_mfa_agent_profile_read_policy_consolidation_v1.sql`
10. `20261101120000_mfa_agent_verification_workflow.sql`
11. `20261101130000_mfa_agent_trust_capital_commission_tables.sql`
12. `20261101131000_mfa_agent_trust_capital_commission_rls.sql`
13. `20261101131500_mfa_partner_admin_aal2.sql`
14. `20261101132000_mfa_agent_trust_capital_commission_workflows.sql`
15. `20261101133000_mfa_public_directory_online_presence.sql`
16. `20261101134000_mfa_legacy_demo_request_security_hardening.sql`
17. `20261101135000_mfa_agent_cfg_supply_activation_gate.sql`
18. `20261101136000_mfa_direct_agent_referral_commission_v1.sql`

## 4. Exact version matches

The following four live migration versions have exact timestamp-prefixed files in the branch:

- `20261031140934` — security hardening
- `20261101035716` — global representation/country offices
- `20261101035950` — global presence AAL2 and column security
- `20261101092738` — RLS auth initplan optimization

The foundation migration does not have an exact filename match: live history says `20261031140915`, while the branch file is `202610310001_mfa_foundation.sql`.

## 5. Live records without exact filename matches

| Live version/name | Possible related branch file(s) | Reconciliation status |
|---|---|---|
| 20261031140915 / mfa_foundation_v1 | `202610310001_mfa_foundation.sql` | Likely same foundation lineage, but timestamp and name differ. Verify full applied SQL/hash. |
| 20261101033516 / mfa_send_receive_requests_v1 | No exact or clearly named branch file | Missing source artifact; recover original migration SQL. |
| 20261101033526 / mfa_request_workflow_fk_indexes | No exact or clearly named branch file | Missing source artifact; recover original migration SQL. |
| 20261101033713 / mfa_agent_request_status_rpc | No exact or clearly named branch file | Missing source artifact; recover original migration SQL. |
| 20261101100622 / mfa_agent_public_directory_privacy_v1 | `20261101100600_mfa_agent_public_directory_privacy_v1.sql` | Name matches but timestamp differs. Branch SQL creates an initial privacy-safe view; compare against applied SQL. |
| 20261101100653 / mfa_agent_public_directory_materialized_privacy_v1 | `20261101100700_mfa_agent_public_directory_materialized_privacy_v1.sql` | Close timestamp/name lineage. Branch SQL replaces view with RLS-protected table; compare exact applied SQL. |
| 20261101102303 / mfa_rls_policy_consolidation_global_presence_v1 | `20261101103000_mfa_rls_policy_consolidation_global_presence_v1.sql` | Name matches, timestamp differs by 7 minutes. Compare exact SQL and policy state. |
| 20261101102331 / mfa_agent_profile_read_policy_consolidation_v1 | `20261101104500_mfa_agent_profile_read_policy_consolidation_v1.sql` | Name matches, timestamp differs. Compare exact SQL and policy state. |
| 20261101104628 / mfa_agent_application_review_rpc_v1 | `20261101120000_mfa_agent_verification_workflow.sql` | Related workflow concept but different timestamp/name. Not proven equivalent; inspect live function body against both artifacts. |

## 6. Branch-only later migrations

The following branch migration files are not listed in the 13 live applied-history records:

- `20261101120000_mfa_agent_verification_workflow.sql`
- `20261101130000_mfa_agent_trust_capital_commission_tables.sql`
- `20261101131000_mfa_agent_trust_capital_commission_rls.sql`
- `20261101131500_mfa_partner_admin_aal2.sql`
- `20261101132000_mfa_agent_trust_capital_commission_workflows.sql`
- `20261101133000_mfa_public_directory_online_presence.sql`
- `20261101134000_mfa_legacy_demo_request_security_hardening.sql`
- `20261101135000_mfa_agent_cfg_supply_activation_gate.sql`
- `20261101136000_mfa_direct_agent_referral_commission_v1.sql`

Do not assume these have been applied live. The catalog snapshot confirms the public directory currently contains only the base projection columns and is a table. The branch-only online-presence migration must therefore not be treated as live state without further proof.

## 7. Source SQL observations from selected files

The branch foundation SQL creates the core profile/agent/support/audit tables, Auth user trigger, helper functions, and initial RLS policies. The branch security-hardening file moves the role helper into a private schema and revokes public execution of the Auth trigger/helper functions.

The branch public-directory sequence is intentionally staged:
- The first privacy migration creates a security-barrier view and grants read access.
- The following migration drops that view and creates a separate RLS-protected table plus a SECURITY DEFINER sync trigger function.

This is consistent with the live catalog's current `public_agent_directory` being an ordinary table, but does not independently prove which exact migration version produced it.

The branch `20261101120000_mfa_agent_verification_workflow.sql` defines the super-admin/AAL2 application-review RPC and forces `transaction_enabled = false`. Live catalog inspection confirms a similarly named live RPC exists, but the applied migration version in history is different. Compare the live function body and exact migration source before treating the branch file as its source.

## 8. Required safe remediation sequence

### Gate A — recover provenance (no database changes)
1. Recover exact original SQL for the three missing request/workflow migrations.
2. Recover the exact SQL applied under live versions `20261031140915`, `20261101100622`, `20261101100653`, `20261101102303`, `20261101102331`, and `20261101104628`.
3. Compare SQL text or normalized DDL effects; document hashes and provenance.
4. Compare live function definitions, triggers, policies, constraints, indexes and grants with the recovered migration effects.

### Gate B — establish a canonical migration set
1. Identify the authoritative migration history and source branch/commit used for the live deployment.
2. Decide whether missing files should be restored as historical artifacts or whether a documented baseline is required. Do not alter historical migration records just to make filenames line up.
3. Ensure branch-only migrations are explicitly marked pending and reviewed in dependency order.
4. Generate a migration diff and schema diff against a disposable/non-production environment.

### Gate C — security and behavior validation
1. Test verified-agent workflow RPCs and admin/AAL2 checks.
2. Test RLS and grants as anon, authenticated owner, unrelated authenticated user, verified agent, and AAL2 super-admin.
3. Test directory sync for verified, pending, rejected, suspended, update, and delete transitions.
4. Verify audit actors and event fields are DB-derived for authoritative records.
5. Verify no MFA workflow can move CFG balances, settle payments, hold funds, release escrow, or make commissions payable.

### Gate D — explicit authorization required
No production migration, migration-history repair, grant change, merge, or deployment is authorized by this report. Each must be separately reviewed and explicitly approved.

## 9. Safety boundary

This reconciliation used only migration-list and repository-read operations. No SQL migration, DDL, DML, grant, policy, Auth, or deployment operation was performed. The feature PR remains Draft/unmerged.
