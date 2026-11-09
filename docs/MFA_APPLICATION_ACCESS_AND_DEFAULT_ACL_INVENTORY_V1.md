# MFA Application Access & Default ACL Inventory V1

**Repository:** `MKONDE/Money-flow-agency`  
**Branch:** `feature/agent-trust-capital-commission-v1`  
**Branch head reviewed:** `1ab4c48e47e17d274c445285a3edebe619eb4568`  
**Supabase project:** `money-flow-agency` (`cabmexujxoosoymsahou`)  
**Date:** 2026-11-09  
**Mode:** Source inspection + read-only catalog query. No changes made.

## 1. Executive summary

The application dependency inventory has started by inspecting the current branch's client components, server actions and Supabase helpers. This first pass found direct browser-client writes in multiple administrative and agent workflows, as well as direct customer writes to tracking/request tables. These call sites must be accounted for before grants can safely be narrowed.

The application uses more than the 19 tables in the earlier public-schema baseline. The code inspected in this pass references additional MFA-specific tables, including `mfa_transactions`, `mfa_agent_capital_profiles`, `mfa_agent_guarantees`, `mfa_agent_trust_badges`, `mfa_transaction_status_history`, `mfa_escrow_workflows`, and `mfa_transaction_disputes`. Therefore, the original 19-table matrix is not a complete application dependency inventory. The complete live table list and all source call sites must be reconciled before a grant diff is designed.

## 2. Observed application table/RPC call sites

This inventory records observed code references, not a statement that each operation succeeds under current grants/RLS.

| Source file / workflow | Observed table or RPC | Operation observed | Caller / context | Least-privilege review |
|---|---|---|---|---|
| `src/app/admin/AgentApplicationReview.tsx` + `src/app/admin/actions.ts` | `profiles` | SELECT role | Server action after authenticated user lookup and AAL2 check | Admin role lookup must remain protected; do not expose profile roles to arbitrary users |
| Same | `mfa_review_agent_application` | RPC | Server action; checks authenticated user, AAL2 and `super_admin` before call | Review SECURITY DEFINER warning and EXECUTE grants; verify RPC repeats authorization server-side |
| `src/app/admin/GlobalPresenceWorkspace.tsx` | `country_representatives` | INSERT, SELECT returned row, UPDATE | Browser client in admin workspace | Confirm AAL2/admin checks are enforced by RLS/RPC, not merely by hiding the UI |
| Same | `country_offices` | INSERT, SELECT returned row, UPDATE | Browser client in admin workspace | Same; resolve public policy/grant mismatch |
| Same | `agent_location_profiles` | UPDATE | Browser client for location review | Must be admin/AAL2 scoped and prevent client-controlled reviewer/decision spoofing |
| Same | `global_presence_audit_log` | INSERT | Browser client after office/representative/location action | Client-side audit inserts are not authoritative; prefer DB-trigger/RPC-generated audit with actor derived from auth context |
| `src/app/admin/agent-supply/AgentCfgSupplyReview.tsx` | `mfa_review_agent_cfg_supply` | RPC | Browser client | Confirm server-side admin/AAL2 authorization and that review cannot activate live payments |
| `src/app/admin/agent-trust/AgentTrustCapitalWorkspace.tsx` | MFA trust/capital/guarantee/tier/transaction/commission/dispute/escrow/country/partner tables and RPCs | Multiple SELECT/INSERT/UPDATE/RPC workflows | Browser client and server actions (full file inspected; call extraction was output-truncated) | Expand exact table/operation list in a follow-up pass; ensure all financial-looking records remain documentary/tracking only |
| `src/app/agent/AgentBrandingForm.tsx` | `agent_profiles` | UPDATE | Browser client; owner agent | Owner may update only branding fields; identity, verification, status and privilege fields must be immutable to owner |
| `src/app/agent/AgentCapitalDeclarationForm.tsx` | `mfa_agent_capital_profiles` | UPSERT | Browser client; owner agent | Owner-scoped declaration only; never interpret as funds held or CFG wallet credit |
| Same | `mfa_agent_guarantees` | INSERT | Browser client; owner agent | Owner-scoped documentary reference; verification status/reviewer fields must be server-controlled |
| `src/app/agent/AgentCfgSupplyForm.tsx` | `mfa_submit_agent_cfg_supply` | RPC | Browser client | RPC must validate agent ownership, claimed amount, idempotency and non-settlement semantics |
| `src/app/agent/AgentLocationForm.tsx` | `agent_location_profiles` | SELECT, INSERT or UPDATE | Browser client; owner agent | Owner-scoped; protect review fields, reviewed_by and approval state |
| `src/app/agent/AgentPresenceToggle.tsx` | `agent_profiles` | UPDATE | Browser client; owner agent | Restrict update to online and consent fields only; consent controls public contact projection |
| `src/app/agent/AgentRequests.tsx` | `agent_update_service_request` | RPC | Browser client; assigned verified agent | SECURITY INVOKER hardening and assignment/status transition tests are required |
| `src/app/agent/AgentTrackedTransactions.tsx` | `mfa_transactions` | UPDATE, SELECT returned row | Browser client; agent tracking | Agent may update only allowed tracking/evidence fields on assigned record; never settle CFG or mark funds received |
| `src/app/agents/page.tsx` | `public_agent_directory` | SELECT | Public server-rendered directory | Public projection only; ensure the additional requested online/payment/contact fields are intentionally public and consent-gated |
| Same | `mfa_agent_trust_badges` | SELECT | Server-side directory page | Return only active public trust badge fields; avoid internal review/history fields |
| `src/app/my-requests/CustomerRequests.tsx` | `service_requests` | INSERT, SELECT returned row | Browser client; customer | Customer may create own demo request only; ensure `demo_only=true` enforced by DB default/check/RLS, not only UI |
| Same | `service_request_events` | INSERT | Browser client after request submission | Client-supplied actor/event fields are spoofable; prefer trusted DB trigger/RPC and derive actor identity server-side |
| `src/app/transactions/CustomerTransactionWorkspace.tsx` | `mfa_transactions` | INSERT, SELECT returned row | Browser client; customer | Enforce `simulation_only=true`, requester identity and allowed fields at DB boundary |
| Same | `mfa_transaction_status_history` | SELECT | Browser client | Participant-scoped read; event history should be server-generated/append-only |
| Same | `mfa_escrow_workflows` | UPDATE customer confirmation timestamp | Browser client; customer | Confirmation should be constrained to transaction participant and one-way/valid state transition; no fund holding or release |
| Same | `mfa_transaction_disputes` | INSERT | Browser client; customer | Only transaction participant can open; preserve non-payable/non-custodial state |
| `src/app/admin/agent-trust/ReferralCommissionSettings.tsx` | `mfa_update_referral_commission_settings` | RPC | Browser client admin UI | Require admin/AAL2 inside RPC; settings affect only future calculation snapshots, never payouts |
| `src/lib/supabase/client.ts` | Supabase browser client | Client factory | Browser components | Never use service-role key; verify only public anon key is used |
| `src/lib/supabase/server.ts` | Supabase server client | Server factory | Server components/actions | Verify cookie-bound user client; privileged service client must be isolated if it exists elsewhere |

### Important code-level risks to test

1. `GlobalPresenceWorkspace.tsx` performs direct browser writes to office/representative/location records and directly inserts audit rows. A client-supplied audit row is not a trusted audit source. Verify DB-side actor derivation, admin/AAL2 enforcement, immutable review fields and audit completeness.
2. `CustomerRequests.tsx` inserts into `service_requests` and then attempts to insert `service_request_events` from the browser. The event insert should not be trusted as an authoritative audit record.
3. `AgentCapitalDeclarationForm.tsx` allows agent-side declaration upsert and guarantee reference insertion. These must never confer verified capital/guarantee status.
4. Customer/agent browser writes to `mfa_transactions` must be tightly scoped to tracking metadata and remain `simulation_only=true`; no client update may settle a transaction or change a commission/payout state.
5. The public agent directory requests `is_online`, `payment_networks`, `public_phone`, and `public_email`. Confirm these columns are in the intended public projection and contact consent is checked before returning phone/email.
6. Admin UI visibility is not authorization. Every RPC and direct table write must enforce role and AAL2 requirements at the database boundary.

## 3. Default ACL owner/grantor provenance — live read-only result

A read-only query against `pg_default_acl`, joining `pg_roles` and `pg_namespace`, returned six default ACL entries for schema `public`:

| Object creator/owner role | Object type | Default privileges granted to anon/authenticated |
|---|---|---|
| `postgres` | Sequences (`S`) | `rwU` |
| `postgres` | Functions (`f`) | `X` (EXECUTE) |
| `postgres` | Tables (`r`) | `arwdDxtm` |
| `supabase_admin` | Sequences (`S`) | `rwU` |
| `supabase_admin` | Functions (`f`) | `X` (EXECUTE) |
| `supabase_admin` | Tables (`r`) | `arwdDxtm` |

The same ACL entries also grant the corresponding privileges to `service_role`; owners retain owner privileges. The entries are owned by two distinct object-creating roles: `postgres` and `supabase_admin`. This resolves the prior uncertainty about the two grantor groups: the defaults are attached to both creator roles, not duplicate rows for one owner.

Interpretation:
- Future tables created by either role in `public` inherit broad table privileges for `anon` and `authenticated`.
- Future sequences inherit sequence privileges for API roles.
- Future functions inherit EXECUTE for API roles.
- This is a high-priority configuration risk. It does not mean every future object is automatically exploitable, but it widens the default permission surface.
- Do not change these defaults yet. First inventory which migration/deployment process creates objects as `postgres` versus `supabase_admin`, and identify existing objects that rely on the defaults.

No ACL was modified.

## 4. Required follow-up to complete inventory

The current source pass is not exhaustive. Complete the remaining work by:

1. Extracting every `.from(`, `.rpc(`, `.storage.from(`, and server-side SQL call from every source file, including the full `AgentTrustCapitalWorkspace.tsx` and all server actions.
2. Listing every live public table and every MFA-specific table, then mapping each source call to table, operation, caller role, fields read/written, and intended authorization.
3. Checking all server-side code for privileged Supabase clients and ensuring service-role secrets are not exposed to browser code.
4. Mapping migration execution identities to `postgres` and `supabase_admin` default ACLs.
5. Comparing this dependency map to the least-privilege target matrix and preparing a proposed staging-only SQL diff.
6. Running negative/positive role tests on isolated staging after the SQL diff is reviewed.

## 5. Explicit non-actions and status

- No grants or default privileges were changed.
- No RLS policies, functions, triggers, tables or Auth settings were changed.
- No migrations were executed.
- No application code was changed.
- No production payments or financial operations were enabled.
- PR #2 remains Draft/unmerged.

**STATUS: FIRST-PASS CALL-SITE INVENTORY COMPLETE; FULL INVENTORY AND STAGING GRANT DIFF STILL BLOCKED ON REMAINING SOURCE EXTRACTION AND ROLE TESTS.**
