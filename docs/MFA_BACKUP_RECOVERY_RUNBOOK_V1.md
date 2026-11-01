# MFA Backup & Recovery Runbook V1

**Scope:** Dedicated Money Flow Agency Supabase project only. Never combine MFA backups with CFG, Jakay, Jakay Pesa or Maharoos Mini.

## Before migrations or releases

1. Confirm the target Supabase project name is money-flow-agency and verify its project reference in the deployment checklist.
2. Review the live migration history and schema drift report. Do not replay migrations against a database that already contains equivalent objects under different migration versions.
3. Take a database backup or point-in-time recovery checkpoint using the Supabase plan's supported controls.
4. Export the current schema and record table row counts for profiles, agent profiles, business partners, service requests/events, partner services, payment partners, receipts and all MFA module tables.
5. Record the Git commit SHA and exact migration filenames being applied.
6. Apply additive migrations to an isolated test/staging database first. Never drop or recreate existing tables to resolve drift.

## Backup configuration

- Enable the Supabase backup/PITR option available on the selected plan before production.
- Restrict backup/restore access to authorized project administrators.
- Retain encrypted exports in an approved private storage location; do not commit backups or production data to GitHub.
- Keep a documented retention schedule and recovery-point objective approved by the owner.
- Back up environment configuration separately using a secrets manager; never store secrets in this repository.

## Restore drill

1. Restore the most recent backup to an isolated recovery project.
2. Verify schema migration history and compare table/row counts with the backup manifest.
3. Verify authentication users, role profiles and RLS policies.
4. Run supabase/tests/mfa_agent_trust_capital_commission_v1.sql.
5. Test login, AAL2 admin access, customer-owned transaction visibility, agent-owned declaration visibility and partner data isolation.
6. Confirm transaction histories, trust histories, dispute events, commission snapshots and audit events remain intact.
7. Verify that simulation_only=true, funds_held=false, release_executed=false and payable=false constraints still exist.
8. Record restore duration, missing data, issues and sign-off before declaring recovery successful.

## Current status

This is a procedure, not proof that backups are configured. Backup/PITR settings, retention, automated exports and a restore drill have not yet been configured or verified for the MFA project. Complete these items before production approval.
