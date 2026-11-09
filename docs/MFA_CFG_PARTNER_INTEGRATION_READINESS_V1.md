# MFA ↔ CFG Partner Channel — Integration Readiness V1

**Status:** ADDITIVE PARTNER BLUEPRINT / NO LIVE MONEY MOVEMENT  
**Repository:** MKONDE/Money-flow-agency  
**Branch:** feature/agent-trust-capital-commission-v1  
**CFG partner repository:** MKONDE/cashflow-gate

## 1. Partner decision

Cashflow Gate (CFG) is the first planned platform partner to use the MFA verified-agent network as an assisted payment channel. MFA remains an independent global agent network and multi-partner platform. CFG is one partner and does not own MFA.

The connection must use a scoped partner API and signed events. Do not merge databases, authentication, customer wallets, balances, ledgers or deployment secrets.

## 2. Role boundaries

MFA owns:
- Agent applications, identity/business profile and verification workflow.
- Agent active/suspended state, country/region, supported networks and service coverage.
- Capital/float declarations and documentary guarantee references.
- Agent assignment and customer-support/tracking workflow.
- Partner-side transaction status mirror and immutable event history.
- Commission calculation snapshots under MFA rules; entries remain non-payable.

CFG owns:
- CFG customer identity and CFG Wallet/account.
- Payment intent creation, amount/currency and fee disclosures.
- Independent verification of external payment settlement.
- All CFG ledger postings and customer balance changes.
- Final financial state and signed status callback to MFA.

MFA agents must never write to CFG Wallet or CFG ledger. CFG must not query MFA database directly.

## 3. Agent workflow for future CFG channel

1. Agent applies through MFA and completes existing verification.
2. Agent configures supported country, region, services, currencies and payment networks.
3. Agent submits capital/float declarations and documentary guarantee references.
4. AAL2 Super Admin reviews the declarations and guarantees and configures the approved currency-specific capital tier.
5. Existing CFG Supply activation rule (minimum verified USD 50 equivalent) must be checked against an authoritative CFG verification source before operational activation. The current branch only supports manual external reference/claimed amount and admin review; no live CFG source/API synchronization exists.
6. Once the agent is approved for the CFG partner channel, MFA exposes only eligible directory/status data through a scoped partner endpoint.
7. A CFG payment intent may be assigned to an eligible MFA agent in a future approved pilot. MFA tracks assistance and evidence only.
8. Agent evidence submission does not mean funds are settled. CFG alone confirms settlement and sends the final signed state.
9. MFA records the final status and calculates any eligible commission snapshot using the approved rule. No commission becomes payable or withdrawable in this V1.

## 4. Partner API and webhook requirements

Proposed contract (provisional):
- Agent availability query scoped by country, currency, network and service.
- Agent-assistance request with opaque CFG payment-intent reference and expiry.
- Assignment/evidence event from MFA to CFG.
- Signed CFG payment-state callback to MFA.
- Status lookup and dispute/reversal notification.

Controls:
- TLS; server-to-server authentication; HMAC/asymmetric signatures; timestamp, nonce, key ID and replay prevention.
- Unique event IDs, idempotency keys and immutable event history.
- Least-privilege scopes and per-partner rate limits.
- Key rotation, revocation, audit logging and monitoring.
- Data minimization: no passwords, service-role keys, full ledger rows or unnecessary identity documents.
- No browser-to-browser secret exchange and no shared Supabase service role.

## 5. Commission separation

The current MFA default allocation (70% Agent / 20% MFA Company / 10% Operations & Risk Reserve) applies only to an explicitly configured commissionable service-fee pool, not automatically to customer payment principal. Historical rule snapshots remain immutable. Referral commission rules remain separate. Commission entries remain payable=false and no payout path is created.

CFG's payment fees and ledger accounting remain exclusively under CFG's approved financial rules. MFA commission rules cannot alter CFG fee rules or balances.

## 6. Current state and blockers

- Agent registration, verification, directory, agent portal, AAL2 admin controls, trust/capital/guarantee declarations, tracking-only transactions and non-payable commission snapshots are implemented at feature-branch code/migration-draft level.
- No live MFA module migrations have been applied; live schema drift requires reconciliation before staging migration replay.
- The current tracking transaction model enforces simulation_only=true.
- No partner API credentials, signed webhooks or provider integration are implemented.
- The USD 50-equivalent CFG Supply activation check is manual/documentary; authoritative CFG verification is not connected.
- Database smoke test, adversarial RLS tests, browser/mobile tests, concurrency tests, backup restore drill and final branch CI verification remain outstanding.
- No live deposits, payment execution, withdrawals, transfers, custody, escrow or commission payouts are enabled.

## 7. Non-negotiable release gates

- Reconcile schema drift in an isolated staging copy; never blindly replay migrations to the shared/live MFA database.
- Apply migrations to staging only after review, then run SQL smoke tests and customer/agent/partner/AAL2-admin RLS tests.
- Build and review the partner API contract and contract tests with CFG.
- Verify settlement, idempotency, replay protection, out-of-order events, reversals, disputes and reconciliation in sandbox.
- Complete legal/compliance, privacy, AML/KYC, consumer protection and agent contract review for every country.
- Obtain separate owner authorization before any live payment pilot, production deployment, merge or real-money operation.

**Principle:** MFA is the first planned CFG agent channel; MFA itself remains independent, and CFG remains the sole authority for CFG balances and financial settlement.
