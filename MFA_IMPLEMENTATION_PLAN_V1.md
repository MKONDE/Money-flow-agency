# MFA Implementation Plan V1

**Project:** Money Flow Agency (MFA)  
**Specification baseline:** Master Blueprint V1 + Master Blueprint V1.1 Additive Edition + MFA–Cashflow Gate Strategic Integration Blueprint V1  
**Working branch:** `feature/mfa-foundation-audit-v1`  
**Base branch:** `main`  
**Status:** Proposed phased implementation plan

## 1. Guiding rules

- Preserve the original Master Blueprint V1. V1.1 features are additive modules.
- MFA is an independent multi-partner platform. CFG is only one partner.
- Keep MFA repository, database, authentication, financial records, credentials and deployment separate from CFG and all other projects.
- Do not write to CFG/CFGG wallet balances or ledger. Receive only authorized payment-status responses through a future scoped Partner API.
- Do not activate real customer deposits, withdrawals, transfers, wallets, custody, crypto exchange, payment execution or real guarantee collection.
- Do not invent unapproved fees, commission rates, advertising prices or transaction limits.
- Use migrations for database changes; preserve existing data and files.
- Work only on `feature/mfa-foundation-audit-v1`. No direct commits to `main`, no merge and no production deployment.

## 2. Repository baseline

The initial audit found no confirmed application framework, package manifest, database configuration or authentication system. The repository is effectively a README-only starting point based on the available inspection. No existing stack should be assumed.

Before application scaffolding, select a supported full-stack framework, database/authentication approach, storage strategy for agent logos/profile images, test runner and deployment preview approach. Record the decision and required environment variables without publishing secret values.

## 3. Delivery phases

### Phase 0 — Audit and architecture decision
- [x] Confirm repository and permissions.
- [x] Confirm requested feature branch exists.
- [x] Inspect README and common root manifests/configuration paths.
- [x] Document audit findings.
- [x] Document implementation plan.
- [ ] Confirm final stack and environment strategy before application scaffolding.
- [ ] Confirm the first pilot country and initial service scope; these remain owner decisions.

### Phase 1 — Secure application foundation
- Create application scaffold and maintainable module boundaries.
- Add environment variable example/documentation with placeholders only.
- Add database schema and versioned migrations.
- Add secure authentication and server-side session handling.
- Add role-based access control for Super Admin, Country Manager, Regional Manager, Verified Agent, Affiliate, Business Partner and Customer.
- Add audit-log foundation, validation, rate limiting and secure error handling.
- Add automated test setup.
- Deny access by default to protected routes and records.

### Phase 2 — Public website
- Responsive, mobile-first home page.
- About, Services, Global Agent Network, Find an Agent, Become an Agent.
- Business Partners and Advertising.
- Help and Complaints, Contact.
- Privacy Policy, Terms and Compliance.
- Clear explanation that a listing or Trust Badge does not guarantee a transaction or financial security.

### Phase 3 — Agent onboarding and directory
- Individual/business registration application.
- Business name, contact information, country, region/city and service address.
- Logo and profile image upload with file type/size validation.
- Services, payment networks and languages.
- Application submission and status tracking.
- Searchable directory with country, region/city, service, payment network, language, verification and online/offline filters.
- Agent states: Pending, Verified, Suspended, Rejected.
- Listing does not grant permission to execute financial transactions.

### Phase 4 — Verification, branding and portals
- Agent profile/branding page and approved service display.
- Admin review queue and approve/reject/suspend/request-information actions.
- Verification evidence and decision reasons with audit trail.
- Trust Badge reflects verification status only.
- Agent Portal: profile, status, approved services, customer requests, transaction references, commission statements, advertising requests, support and security settings.
- Admin Portal: agent metrics, partners, locations, permissions, advertising, commission configuration, guarantee status, complaints/disputes, transaction references, audit logs and system settings.
- Enforce ownership and role checks server-side.

### Phase 5 — Additive V1.1 modules
Build as independently configurable modules:
1. Agent Network & Listing.
2. Agent Branding & Advertising, including approval and publication schedule.
3. Fee & Commission Engine for service, agent, partner and multi-level affiliate commissions. Use configurable versioned rules; do not invent rates. Add idempotency.
4. Business Partner Integration with partner profiles, approval/contract state, scoped credentials, usage limits, isolated data access and API logs.
5. Agent Requests, Support & Complaints with reference numbers and New, Assigned, In Progress, Resolved, Closed statuses.
6. Escrow & Agent Guarantee Engine in sandbox/test state only, with separate agent statements and available/reserved/disputed/released classifications, reconciliation, limits and dispute/refund workflows.

### Phase 6 — Partner API and CFG readiness
- Define partner-agnostic API contracts.
- Authenticate partner requests with scoped credentials and signature verification.
- Add rate limits, idempotency keys, request correlation IDs and API logs.
- Accept transaction references and return only authorized status information.
- CFG remains owner of its business, wallet, balances, ledger and payment confirmation.
- No direct MFA-to-CFG database or ledger access.
- Test unauthorized access, duplicate requests/webhooks, timeouts, reversals, refunds and disputes in a sandbox.

### Phase 7 — Security, quality and handover
- Test role permissions and partner data isolation.
- Test agent verification lifecycle and Trust Badge correctness.
- Test upload validation, input validation and rate limits.
- Test idempotency and historical rule-version references.
- Verify secrets are absent from source control.
- Document backup/restore and run restore testing when infrastructure is available.
- Run automated tests, lint/type checks and build.
- Produce remaining-work, security and test reports.
- Provide preview instructions; do not deploy production or merge to `main`.

## 4. Data and permission design principles

- Every partner-owned record must be scoped to the relevant partner/tenant where applicable.
- Agents may read and update only their own permitted records.
- Managers may act only within assigned country/region scope.
- Super Admin actions must be authenticated, authorized and audited.
- A listed agent, verified agent and transaction-enabled agent are separate states/permissions.
- Transaction-enabled status requires approved service permission and all applicable guarantee/legal controls.
- Trust Badge is a statement of verification status, not a promise of financial safety.
- Commission calculations must reference the exact immutable rule version used for the transaction and must be idempotent.
- No real funds or simulated balances may be presented as received or available.

## 5. Guarantee / bank-account controls

The preferred arrangement is an approved third-party bank/escrow structure. A separate designated MFA bank account may be evaluated only if escrow is unavailable and the bank and legal adviser approve it. It must not be an ordinary operating account. Agent deposits must remain segregated, must not fund normal expenses and must not be mixed with CFG/CFGG or another partner's funds.

Until legal and banking approval is documented:
- Keep the guarantee module in sandbox/test mode.
- Do not publish real deposit instructions.
- Do not accept real deposits.
- Do not grant transaction permissions that require a guarantee.
- Do not treat screenshots alone as proof of deposit.

## 6. Decisions requiring owner confirmation

- First registration/operating countries and pilot regions.
- Initial services to be offered.
- Final company name and domain after legal/trademark checks.
- Approved payment providers and signed agreements.
- Fees, commissions, advertising prices and transaction limits.
- Banking/legal structure for agent guarantees.
- Final hosting and production deployment arrangements.

## 7. Acceptance criteria

- Public pages are responsive and navigable.
- Agent applications can be submitted and tracked.
- Directory filters work and only approved public profile data is exposed.
- Admin can review applications and record evidence/reasons.
- Trust Badge matches verification state and does not imply transaction guarantee.
- Agent and admin portals enforce server-side role and ownership permissions.
- Partner API uses authentication, scopes, rate limits, idempotency and logs.
- Fee/commission history retains the exact rule version.
- Guarantee collection and real-money operations remain disabled pending approval.
- No MFA code path can directly modify CFG/CFGG balances or ledger.
- Automated tests, security findings and remaining work are documented.

## 8. Current progress

- Initial remote repository audit: documented.
- Implementation plan: documented.
- Application code: not yet started.
- Database migrations: not yet created.
- Tests: not yet configured or run.
- Preview/deployment: not performed.
