# MFA Live Database Catalog Reconciliation V1

**Project:** Money Flow Agency (MFA)  
**Supabase project ref:** `cabmexujxoosoymsahou`  
**Scope:** Read-only live PostgreSQL catalog inspection  
**Status:** Inventory findings recorded; no database changes made.

## 1. Executive summary

The live `public` schema currently exposes **19 ordinary tables and 2 sequences** in the catalog query. All 19 tables have RLS enabled; none has FORCE ROW LEVEL SECURITY enabled. The catalog query returned no public views, materialized views, partitioned tables, or foreign tables.

The source dependency map previously identified `mfa_agent_exposure_summary` as a possible view/table dependency. It is **not present as a relation in the live public schema** under that exact name. The public directory is an ordinary table, not a view or materialized view.

Three public SECURITY DEFINER functions of particular relevance were confirmed:
- `agent_update_service_request(uuid,text,text)`
- `mfa_review_agent_application(uuid,text,text,text)`
- `sync_public_agent_directory()`

All three have an empty configured search_path. The first two are executable by `authenticated`; the directory sync function is not granted to anon/authenticated in the inspected ACL. The two callable workflow functions remain a priority for source/live reconciliation and hardening review. This report does not alter them.

## 2. Relation inventory

| Catalog object type | Count | RLS enabled | FORCE RLS |
|---|---:|---:|---:|
| Ordinary tables | 19 | 19 | 0 |
| Sequences | 2 | N/A | N/A |
| Views | 0 | N/A | N/A |
| Materialized views | 0 | N/A | N/A |
| Partitioned tables | 0 | N/A | N/A |
| Foreign tables | 0 | N/A | N/A |

RLS enabled without FORCE is not, by itself, proof of an exploitable issue. Table owners and privileged roles can have different RLS behavior; policy and role-path testing is still required.

## 3. Named dependency reconciliation

| Name | Live catalog result | Finding |
|---|---|---|
| `mfa_agent_exposure_summary` | Not found in public relations | Source code dependency requires reconciliation. Do not assume it is a table or view. |
| `public_agent_directory` | Ordinary table; RLS enabled; FORCE RLS off | Not a view/materialized view. |
| `global_presence_audit_log` | Ordinary table; RLS enabled; FORCE RLS off | Has client-visible audit data shape; verify writes are server/DB-derived and not trusted from browser payloads. |
| `service_request_events` | Ordinary table; RLS enabled; FORCE RLS off | Has actor/event fields; browser-supplied event inserts must not be treated as authoritative audit evidence. |

### Public directory columns

The live `public_agent_directory` table contains:
`id, brand_name, description, country_code, region, city, services, languages, logo_url, synced_at`.

This projection does not include phone, email, street address, or the additional online/payment/contact fields requested by some application code. Verify the UI handles absent fields safely and does not imply those fields are live directory data.

## 4. Trigger and function findings

The live public schema has six non-internal trigger rows across five tables:

- `agent_location_profiles.agent_location_profiles_updated_at` → `set_global_presence_updated_at()`
- `agent_profiles.agent_profiles_set_updated_at` → `set_updated_at()`
- `agent_profiles.sync_public_agent_directory_trigger` → `sync_public_agent_directory()`
- `country_offices.country_offices_updated_at` → `set_global_presence_updated_at()`
- `country_representatives.country_representatives_updated_at` → `set_global_presence_updated_at()`
- `profiles.profiles_set_updated_at` → `set_updated_at()`

The directory sync trigger fires after INSERT or updates to selected branding/location/status columns on `agent_profiles`. Its SECURITY DEFINER function copies verified agents' public branding/location fields into `public_agent_directory`, and removes directory rows when an agent is not verified. It has an empty search_path and uses schema-qualified references for directory writes.

The two workflow RPCs are SECURITY DEFINER with empty search_path and authenticated EXECUTE grants. Their exact function bodies and policy paths should be reviewed against the current feature-branch migration and adversarial test cases before any live change.

## 5. Default privilege findings

The live `pg_default_acl` inventory contains default ACL entries for both creator roles:
- `postgres`
- `supabase_admin`

For both creators, default privileges include broad table privileges for `anon` and `authenticated`, sequence SELECT/UPDATE/USAGE, and function EXECUTE. Table privilege sets include INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES and TRIGGER (as well as SELECT). This is a high-priority default-privilege design concern because future objects created by those roles may inherit broad grants.

**No default privileges were changed.** Before remediation, identify which roles actually create migrations/objects in the deployment process, inspect object-specific ACLs and application usage, and prepare a staged least-privilege plan with regression tests. Do not blindly revoke grants or change defaults in production.

## 6. Security interpretation and next checks

1. Reconcile all 19 live tables with source migration files and application dependencies, including the missing `mfa_agent_exposure_summary` reference.
2. Review per-object grants and RLS policies separately; catalog grants alone do not establish effective row access.
3. Confirm authenticated users cannot invoke privileged workflow RPCs outside the intended verified-agent/admin conditions.
4. Verify AAL2 and super-admin enforcement occurs inside database functions/RPCs for every administrative write.
5. Replace browser-originated audit event writes with DB-derived actor/action snapshots where audit evidence is security-critical.
6. Test owner-field allowlists and immutable reviewer/approval fields.
7. Confirm public directory consent rules and that the app only displays fields present in the live projection.
8. Identify migration creator roles before changing default ACLs.
9. Continue migration-history reconciliation and test in a non-production environment before any proposed migration.
10. Keep MFA strictly documentary/simulation-only: no CFG ledger writes, no custody, no live settlement, no escrow release and no payable commission.

## 7. Change log / safety boundary

- Read-only catalog queries only.
- No schema, data, grant, policy, function, Auth, or migration changes.
- No payment, transfer, custody, settlement, or commission operation.
- No production deployment, merge, or PR state change.
- Findings are a live catalog snapshot and should be revalidated before remediation.

