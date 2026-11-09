# MFA Full Application Dependency Map V1 — Addendum

**Repository:** `MKONDE/Money-flow-agency`  
**Branch:** `feature/agent-trust-capital-commission-v1`  
**Reviewed branch head:** `e71067f15b88723c5540bbcd8e4b7751e085dbb1`  
**Date:** 2026-11-09  
**Method:** Git tree enumeration and source inspection; no live changes.

## 1. Scope and result

This addendum expands `MFA_APPLICATION_ACCESS_AND_DEFAULT_ACL_INVENTORY_V1.md`. It captures server-side reads and direct browser write paths from the current application routes and workspaces. It is a source-code dependency map, not proof that RLS or grants currently allow every operation.

The app's Supabase client factories use `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` in both browser and server clients. The inspected factories do not use a service-role key. This is positive, but the full repository still requires a global secret scan and review of any future privileged client.

## 2. Route-level read dependencies

| Route / source | Tables read | Purpose / expected scope |
|---|---|---|
| `src/app/admin/page.tsx` | `profiles`, `agent_profiles`, `service_requests`, `country_representatives`, `country_offices`, `agent_location_profiles` | Admin role check and admin dashboard queues. Must be super-admin/AAL2 for sensitive admin data and operations. |
| `src/app/admin/agent-trust/page.tsx` | `profiles`, `agent_profiles`, `mfa_agent_trust_badges`, `mfa_agent_trust_history`, `mfa_agent_capital_profiles`, `mfa_agent_guarantees`, `mfa_capital_tiers`, `mfa_transactions`, `mfa_transaction_status_history`, `mfa_agent_exposure_summary`, `mfa_transaction_disputes`, `mfa_commission_rules`, `mfa_commission_entries`, `mfa_country_settings`, `business_partners`, `mfa_escrow_workflows`, `mfa_financial_audit_events`, `mfa_referral_commission_settings` | Sensitive admin console. All reads must be admin-authorized server-side; client route gating alone is insufficient. |
| `src/app/agent/page.tsx` | `agent_profiles`, `agent_location_profiles`, `mfa_agent_capital_profiles`, `mfa_agent_guarantees`, `mfa_agent_trust_badges`, `service_requests`, `mfa_transactions`, `mfa_commission_entries`, `mfa_agent_cfg_supply`, `mfa_referral_commission_entries` | Authenticated agent's own profile, documentary capital/guarantee, assigned tracking records and commission snapshots. All rows must be scoped to the authenticated agent. |
| `src/app/agents/page.tsx` | `public_agent_directory`, `mfa_agent_trust_badges` | Public directory projection and public active trust badges. Contact fields must be consent-gated. |
| `src/app/transactions/page.tsx` | `mfa_transactions`, `mfa_country_settings`, `mfa_transaction_status_history`, `mfa_escrow_workflows`, `mfa_transaction_disputes` | Customer's own simulated transaction history, country config and related tracking metadata. |
| `src/app/my-requests/page.tsx` | `service_requests` | Authenticated customer's own demo requests. |
| `src/app/admin/agent-trust/ReferralCommissionSettings.tsx` | `mfa_referral_commission_settings` (initial read is supplied by server page) | Admin referral calculation settings; future accrual snapshots only, no payouts. |

## 3. Direct browser write dependencies

| Source / workflow | Table or RPC | Operation | Authorization and hardening requirement |
|---|---|---|---|
| `src/app/admin/GlobalPresenceWorkspace.tsx` | `country_representatives` | INSERT, UPDATE | Admin/AAL2 only; validate country code, verified status, publication and allowed columns server-side. |
| Same | `country_offices` | INSERT, UPDATE | Admin/AAL2 only; no self-asserted verification without evidence/review controls. |
| Same | `agent_location_profiles` | UPDATE | Admin/AAL2 only; reviewed_by/reviewed_at/status must be server-derived and audit-bound. |
| Same | `global_presence_audit_log` | INSERT | Do not trust browser-supplied actor/action/after_data as authoritative audit. Prefer RPC/trigger that derives actor and captures DB-side before/after state. |
| `src/app/admin/agent-supply/AgentCfgSupplyReview.tsx` | `mfa_review_agent_cfg_supply` | RPC | Enforce super-admin/AAL2 and immutable review audit inside function; this must never settle CFG. |
| `src/app/admin/agent-trust/AgentTrustCapitalWorkspace.tsx` | `mfa_agent_guarantees` | UPDATE | Admin/AAL2 verification of documentary reference; verified_by/time must be server-derived. |
| Same | `mfa_agent_trust_badges` | UPDATE | Admin/AAL2; badge history should be DB-generated and immutable. |
| Same | `mfa_capital_tiers` | INSERT, UPDATE | Admin/AAL2; currency, bounds, effective date and no retroactive rewriting of completed records. |
| Same | `mfa_commission_rules` | INSERT, UPDATE | Admin/AAL2; enforce shares sum to 100, scope uniqueness/effectivity and preserve historical snapshots. |
| Same | `mfa_transactions` | UPDATE | Admin assignment/tracking only; validate agent, partner, allowed status transition and commissionable fee pool. Never allow CFG ledger settlement. |
| Same | `mfa_transaction_disputes` | UPDATE | Admin/AAL2; only valid open/under-review transitions; resolved_by/time must be server-derived. |
| Same | `mfa_country_settings` | INSERT/UPSERT, UPDATE | Admin/AAL2; validate country/currency config and preserve historical currency snapshots. |
| Same | `mfa_escrow_workflows` | INSERT, UPDATE | Metadata-only; DB constraints must keep `funds_held=false`, `release_executed=false`; no escrow/custody action. |
| Same | `business_partners` | UPDATE | Admin/AAL2; contract status transitions only, audit all decisions. |
| `src/app/admin/agent-trust/ReferralCommissionSettings.tsx` | `mfa_update_referral_commission_settings` | RPC | Admin/AAL2 enforced in RPC; changes apply only to future snapshots; never create payable balances. |
| `src/app/agent/AgentBrandingForm.tsx` | `agent_profiles` | UPDATE | Owner may change logo/branding fields only. |
| `src/app/agent/AgentCapitalDeclarationForm.tsx` | `mfa_agent_capital_profiles` | UPSERT | Agent may submit own declaration only; declaration is not custody, balance or verified funds. |
| Same | `mfa_agent_guarantees` | INSERT | Agent may submit own documentary reference; cannot set verification outcome or reviewer fields. |
| `src/app/agent/AgentCfgSupplyForm.tsx` | `mfa_submit_agent_cfg_supply` | RPC | Own-agent submission only; verify claimed minimum and references. It must not issue CFG, credit wallet or settle a payment. |
| `src/app/agent/AgentLocationForm.tsx` | `agent_location_profiles` | SELECT, INSERT, UPDATE | Own agent only; owner cannot set approval/reviewer fields. |
| `src/app/agent/AgentPresenceToggle.tsx` | `agent_profiles` | UPDATE | Owner may update only `is_online` and `public_contact_consent`. |
| `src/app/agent/AgentRequests.tsx` | `agent_update_service_request` | RPC | Assigned verified agent only; legal status transitions, SECURITY INVOKER preferred and no financial effects. |
| `src/app/agent/AgentTrackedTransactions.tsx` | `mfa_transactions` | UPDATE | Assigned agent may update evidence/allowed tracking fields only; no amount, requester, settlement or commission mutation. |
| `src/app/my-requests/CustomerRequests.tsx` | `service_requests` | INSERT | Own customer demo request only; DB enforces `demo_only=true` and actor identity. |
| Same | `service_request_events` | INSERT | Browser-supplied event actor is not authoritative. Replace with trigger/RPC deriving actor and event fields. |
| `src/app/transactions/CustomerTransactionWorkspace.tsx` | `mfa_transactions` | INSERT | Own customer simulated record only; DB enforces `simulation_only=true`, requester identity and immutable principal/settlement fields. |
| Same | `mfa_escrow_workflows` | UPDATE | Customer confirmation only for own transaction and valid state; cannot hold or release funds. |
| Same | `mfa_transaction_disputes` | INSERT | Customer participant only; one valid dispute path, no payout or settlement side effect. |

## 4. Auth signup path

`src/components/agent-application-form.tsx` uses Supabase Auth `signUp`, placing application fields in user metadata. It does not directly insert an agent profile from the browser. The DB-side profile/application provisioning trigger or callback must be verified for:
- metadata validation and allowed fields;
- preventing user metadata from setting verified/active/admin/transaction-enabled flags;
- ensuring referral code attribution is validated server-side;
- keeping new agent status pending and transaction capability disabled;
- not exposing full phone, email or service address in the public directory without explicit consent.

## 5. Data model dependency inventory (source references)

### Identity, profile and public presence
`profiles`, `agent_profiles`, `agent_location_profiles`, `public_agent_directory`, `mfa_agent_trust_badges`, `mfa_agent_trust_history`, `country_representatives`, `country_offices`, `global_presence_audit_log`.

### Requests and customer service
`service_requests`, `service_request_events`, `mfa_transactions`, `mfa_transaction_status_history`, `mfa_transaction_disputes`, `mfa_escrow_workflows`.

### Agent capital, CFG supply and limits
`mfa_agent_capital_profiles`, `mfa_agent_guarantees`, `mfa_agent_cfg_supply`, `mfa_capital_tiers`, `mfa_agent_exposure_summary`.

### Partner, commission and configuration
`business_partners`, `mfa_commission_rules`, `mfa_commission_entries`, `mfa_referral_commission_settings`, `mfa_referral_commission_entries`, `mfa_country_settings`, `mfa_financial_audit_events`.

This is a union of observed source references, not a declaration that every item is a physical table. For example, `mfa_agent_exposure_summary` may be a view; its object type must be verified from the live catalog. A physical table/view/function inventory must be reconciled separately.

## 6. Supabase client and privileged access finding

Both `src/lib/supabase/client.ts` and `src/lib/supabase/server.ts` use the public publishable key. No service-role client was found in these two factories. A repository-wide search of all server code, scripts, CI variables and deployment environment remains required before certifying that no privileged key is bundled or exposed.

## 7. Priority remediation sequence — proposal only

**P0 — before staging grant changes**
1. Replace client-written audit events with trusted DB-side audit generation for `global_presence_audit_log` and `service_request_events`.
2. Confirm all admin direct writes have database-enforced super-admin + AAL2 authorization, not UI-only protection.
3. Restrict owner updates to explicit field allowlists for agent profile, location, capital and transaction tracking.
4. Confirm customer and agent operations cannot change `simulation_only`, `demo_only`, transaction principal, settlement state, `funds_held`, `release_executed`, payable/payout fields.
5. Check `public_agent_directory` contact fields are returned only where public consent is true.

**P1 — before staging tests**
6. Inventory every live object type (table, view, materialized view, sequence, function) and its grants.
7. Resolve default ACLs for both `postgres` and `supabase_admin` with migration-owner provenance. Do not revoke defaults until all object creation paths are known.
8. Reconcile migration history/file drift. Do not infer equivalence from migration names or timestamps.

**P2 — staging validation**
9. Build a role matrix for anon, authenticated customer, verified agent, unverified agent, super_admin without AAL2, super_admin with AAL2, and service_role.
10. Add positive and negative SQL/API tests for every write path above.
11. Only after passing tests, prepare a staging-only grant/RLS migration proposal for separate review.

## 8. Explicit non-actions

- No Supabase grants, default ACLs, RLS policies, functions, triggers, tables or Auth settings were changed.
- No migration was executed.
- No application source code was changed.
- No payment, escrow, custody, CFG settlement or commission payout was activated.
- MFA remains separate from CFG; no shared database or authentication was introduced.
- PR #2 remains Draft/unmerged.

**STATUS: ROUTE-LEVEL READ/WRITE DEPENDENCY MAP ADDED. NEXT GATE: LIVE OBJECT-TYPE/GRANT RECONCILIATION AND TRUSTED-AUDIT DESIGN BEFORE ANY STAGING SQL.**
