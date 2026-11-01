# MFA Send & Receive Operations V1
## Additive technical blueprint — draft for owner review

**Status:** Blueprint approved in principle; implementation not yet started.  
**Repository:** `MKONDE/Money-flow-agency`  
**Working branch:** `feature/mfa-foundation-audit-v1`  
**Scope rule:** Additive to MFA V1. Do not alter existing identity, agent verification, partner, security, or deployment decisions without separate approval.

## 1. Purpose

Provide a multi-partner service-discovery and transaction-request workspace where customers can find an approved agent or payment partner, choose how they want to be served, submit a request, follow its progress, and receive a receipt or provider confirmation.

MFA is the coordination, discovery, request-tracking, support, and evidence layer. It is not a pooled wallet, bank, payment processor, custodian, crypto exchange, or settlement ledger.

## 2. Supported service modes

### 2.1 Self-Service
The customer initiates and completes the payment or transfer directly through the partner's official app, hosted checkout, API, or other approved channel. MFA may create a request/reference and display status returned by the partner. MFA must not collect the customer's PIN, OTP, password, card security code, seed phrase, or private key.

### 2.2 Agent-Assisted
The customer requests help from an eligible agent. The agent follows the partner's approved process using the agent's own authorized access or a partner-provided agent interface. The customer personally performs any sensitive authentication or authorization step. Agent-assisted service must not mean the agent receives or stores customer credentials.

Each listing and request must clearly show which mode is offered. An agent may offer one or both modes, subject to partner approval and applicable law.

## 3. Service categories and partner directory

The partner directory may catalogue these categories, subject to due diligence, contracts, licensing and technical readiness:

- Banks and regulated financial institutions
- Mobile money networks (for example M-Pesa and Tigo Pesa)
- Jakay Pesa
- Card networks and approved card-payment providers (for example Visa-enabled services)
- E-wallet providers (for example Skrill and Neteller)
- Digital-asset providers and supported assets (for example USDT, Bitcoin and other approved coins)
- Cashflow Gate (CFG) services
- Other approved local or international payment providers

A name in the catalogue is not evidence of an active integration or endorsement. Every provider and service must have a capability state: `listed`, `under_review`, `approved_manual`, `approved_api`, `suspended`, or `retired`.

## 4. Customer journey

1. Customer opens **Send Money** or **Receive Money**.
2. Customer selects country, currency, service category and partner/network.
3. MFA displays eligible services and verified agents, with mode, supported corridor, limits, fees (where approved), hours and availability.
4. Customer selects Self-Service or Agent-Assisted.
5. Customer enters only the minimum information required for a service request. Sensitive credentials are never requested.
6. MFA creates a unique request reference and records consent and the displayed service terms.
7. Self-Service: customer continues through the partner's official channel. Agent-Assisted: the selected agent accepts or declines the request and follows the approved partner workflow.
8. Status is updated from a trusted partner callback/API where available, or by a controlled manual evidence workflow clearly labelled as unverified/pending partner confirmation.
9. When the partner confirms completion, MFA displays the partner reference and a receipt/status record. An uploaded screenshot alone is not proof of settlement.
10. Customer can raise a dispute or support ticket.

## 5. Agent Transaction Workspace

Add a new section to the existing agent portal. It must not imply that the currently minimal portal already contains these features.

Proposed navigation:
- Overview
- Service Listings
- New Requests
- Active Requests
- Completed Requests
- Cancelled / Expired Requests
- Receipts & Evidence
- Service Performance
- Disputes & Support
- Availability & Working Hours

Agent profile and service listing are separate:
- Agent profile describes identity, business, location, verification and contact channels.
- Service listing describes the particular partner, operation, corridor, mode, currencies, limits, hours, fee disclosure and approval state.

An agent must not activate a regulated or partner-controlled service merely by selecting a checkbox. Activation requires MFA review and, where applicable, partner approval and evidence of authorization.

## 6. Send and Receive operation model

A request should identify:
- Direction: `send` or `receive`
- Mode: `self_service` or `agent_assisted`
- Customer, selected agent (optional for self-service), and partner
- Origin and destination country/currency where relevant
- Requested amount and currency
- Recipient or beneficiary details, minimised and protected
- Quote/fee disclosure version and expiry, if applicable
- Status and status history
- Partner reference (when issued)
- Receipt/evidence references
- Created, accepted, expired and completed timestamps

MFA must distinguish a **service request** from a **financial transaction**. Creating or completing a request record does not itself move money.

Suggested request states:
`draft` → `submitted` → `awaiting_agent` (agent-assisted) → `accepted` → `processing` → `partner_pending_confirmation` → `completed`

Alternative terminal states: `declined`, `cancelled`, `expired`, `failed`, `disputed`, `under_review`.

Only a trusted partner confirmation or an authorized, audited review process may mark a request as financially completed. Manual agent claims must not automatically become verified settlement.

## 7. Receipts and proof

Receipt record should include:
- MFA request reference
- Partner name and partner transaction reference, if available
- Direction, date/time, amount and currency as confirmed by the partner
- Status and source of confirmation (`partner_api`, `partner_webhook`, `partner_portal_review`, or `manual_unverified`)
- Agent identity where agent-assisted
- Customer-visible fee disclosure and receipt version
- A verification indicator

MFA-generated acknowledgement of a request must be labelled **Request received — not proof of payment**. A receipt based only on manual evidence must be labelled **Pending independent verification** until reviewed.

## 8. Proposed data model (design only; no migration in this change)

Potential tables, subject to schema and RLS review:
- `payment_partners`: provider identity, category, countries, contract/capability status, support contacts.
- `partner_services`: direction, rails, currencies, corridors, modes, limits, fee configuration reference, approval state.
- `agent_service_listings`: agent, partner service, modes offered, availability, approved limits and public description.
- `service_requests`: customer request, direction, mode, partner/service, agent, amount/currency, status and references.
- `service_request_events`: append-only status and actor history.
- `partner_confirmations`: provider reference, callback/manual source, confirmation state and timestamps.
- `receipt_records`: customer-facing receipt metadata and verification label.
- `evidence_objects`: private storage references, evidence type, uploader and review state.
- `service_disputes`: dispute reason, status, assigned reviewer and resolution record.
- `partner_terms_versions`: versioned fee/terms disclosures accepted by customer.

Do not create or use MFA customer wallets, pooled balances, settlement accounts, partner ledgers, or a cross-partner balance table. Do not store card data, wallet credentials, PINs, OTPs, seed phrases or private keys.

## 9. Security, privacy and access control

- Enforce Row Level Security on every new table.
- Customers can read their own requests and receipts; agents can read only requests assigned to them; partner access is scoped to that partner's data; authorized MFA staff have audited review permissions.
- Never trust client-supplied agent IDs, partner IDs, amounts, status, fee values, or completion flags. Validate on the server.
- Status transitions must be server-controlled and audited.
- Use idempotency keys for partner callbacks and request creation to prevent duplicates.
- Verify webhook signatures and replay protection before accepting partner status.
- Keep evidence in private storage with short-lived signed access; restrict file types and sizes; malware-scan where available.
- Minimise beneficiary data and define retention/deletion periods with legal review.
- Never expose Supabase service-role credentials in the browser.
- Do not disable Vercel preview protection or add production secrets as part of this blueprint.

## 10. Partner integration architecture

Use a provider adapter boundary so each provider can be integrated independently. A provider adapter may support:
- Hosted checkout/deep link
- Partner API
- Signed webhook/callback
- Agent portal/manual workflow
- Status inquiry/reconciliation

Each capability must be explicitly recorded. Do not advertise a provider as API-integrated until sandbox tests, security review, commercial agreement and required approvals are complete.

CFG and CFGG remain separate systems. MFA may display a CFG service request and partner-confirmed status through an authorized integration, but CFG/CFGG retain their own wallets, balances, internal money, transaction records and ledgers. MFA must never write directly to CFG/CFGG balances or ledgers. Apply the same separation to Jakay Pesa and all other providers.

## 11. Fees and agent earnings

V1 blueprint supports displaying a partner-approved fee/commission disclosure, not executing settlement or paying commissions. Fee schedules must be versioned so a request retains the terms accepted at creation. Any later fee/commission engine requires a separate approved design, legal review, accounting treatment and security assessment. Do not calculate or promise earnings from unverified or failed requests.

## 12. Rollout phases

**Phase 0 — design and controls**
- Confirm partner categories, customer journey, roles, privacy fields and legal boundaries.
- Review schema, RLS matrix, status transitions and threat model.
- No live transfers.

**Phase 1 — directory and request tracking (sandbox/demo)**
- Partner/service catalogue with capability labels.
- Agent service listings and availability.
- Customer request creation and status tracking using demo records only.
- Agent workspace and customer receipt acknowledgement clearly marked non-payment proof.

**Phase 2 — controlled manual partner workflow**
- Only after provider contracts and approvals.
- Evidence upload, reviewer queue, dispute workflow and audit trail.
- Manual evidence remains distinct from independently verified partner settlement.

**Phase 3 — partner sandbox/API integrations**
- One provider at a time.
- Signed callbacks, idempotency, status inquiry, reconciliation and security testing.
- No production money movement until explicit owner approval and all legal/provider requirements are met.

**Phase 4 — production enablement**
- Requires a separate written go-live decision, legal/compliance sign-off, partner approval, operational support, incident response, reconciliation and security sign-off. This blueprint does not authorize production transactions.

## 13. Fit with current MFA V1 repository

Repository review on `feature/mfa-foundation-audit-v1` found:
- `src/app/agent/page.tsx` currently shows a minimal agent portal: application status, location, transaction permission flag, profile description and services. It explicitly says financial transactions are not available.
- Existing schema includes `agent_profiles.payment_networks`, `agent_profiles.services`, `agent_profiles.transaction_enabled`, and `business_partners`.
- Existing README says MFA serves multiple partners and real deposits, withdrawals, transfers, wallets, custody, crypto exchange and payment execution remain disabled.
- README lists partner API, agent search filters, fee/commission engine, advertising approvals and guarantee workflows as incomplete.

Therefore this module is **not already implemented**. It is an additive design extending the existing partner directory, agent profile and portal foundations. Existing `payment_networks` is only a profile attribute; it is not a verified partner integration or transaction capability. Existing `transaction_enabled` must not be treated as permission to move money.

## 14. Explicit exclusions and owner decisions still required

This blueprint does not authorize:
- Real customer deposits, withdrawals, transfers or payment execution
- Holding customer or partner funds, escrow, pooled accounts or custody
- Crypto exchange, conversion, brokerage or private-key handling
- Guarantee collection or financial guarantees
- Production API credentials, production webhooks or production deployment
- Automatic agent commissions or settlement

Before implementation beyond demo/request tracking, owner must approve the detailed RLS matrix, data fields, retention policy, partner onboarding checklist, country-by-country legal assessment, and the first provider/corridor to pilot.

---
**Decision record:** Customer may choose Self-Service or Agent-Assisted. Agent service advertisements link directly to the corresponding service request flow. All partners retain their own financial systems and authoritative transaction records.
