# MFA Implementation Plan V1

**Project:** Money Flow Agency (MFA)  
**Specification baseline:** Master Blueprint V1 + Master Blueprint V1.1 Additive Edition + MFA–Cashflow Gate Strategic Integration Blueprint V1  
**Working branch:** `feature/mfa-foundation-audit-v1`  
**Base branch:** `main`  
**Status:** Foundation scaffold committed; validation and remaining modules in progress

## 1. Guiding rules

- Preserve original Master Blueprint V1. V1.1 features are additive.
- MFA is an independent multi-partner platform; CFG is only one partner.
- Keep MFA repository, database, authentication, financial records, credentials and deployment separate from CFG and all other projects.
- Never write to CFG/CFGG wallet balances or ledger.
- Keep real customer deposits, withdrawals, transfers, wallets, custody, crypto exchange, payment execution and guarantee collection disabled.
- Do not invent unapproved fees, commission rates, advertising prices or transaction limits.
- Use migrations for database changes; preserve existing data and files.
- Work only on `feature/mfa-foundation-audit-v1`. No direct commits to `main`, no merge and no production deployment.

## 2. Approved technical stack

- Next.js App Router 16 + TypeScript.
- Supabase PostgreSQL and Auth.
- `@supabase/ssr` cookie-based sessions for Next.js.
- Vercel preview hosting, to be configured only after owner review.
- Dedicated Supabase project and credentials for MFA only.

## 3. Delivery phases and progress

### Phase 0 — Audit and architecture
- [x] Confirm repository, permissions and feature branch.
- [x] Inspect README and common root paths.
- [x] Commit repository audit and implementation plan.
- [x] Owner approved Next.js + TypeScript + Supabase + Vercel preview architecture.
- [ ] Confirm first pilot country and initial services; owner decision required.

### Phase 1 — Secure application foundation
- [x] Create Next.js App Router/TypeScript scaffold.
- [x] Add environment variable example with placeholders only.
- [x] Add Supabase browser/server SSR clients and Next.js proxy session refresh.
- [x] Add initial database migration.
- [x] Enable RLS on initial tables.
- [x] Prevent user self-promotion through profile role column grants.
- [x] Prevent agents from changing verification state or transaction-enabled flag through user grants.
- [ ] Provision dedicated MFA Supabase project and apply migration.
- [ ] Configure email confirmation and administrator MFA.
- [x] Add Super Admin-only AAL2 agent review RPC, server action and Admin review UI.\n- [ ] Add controlled Super Admin account provisioning procedure.
- [x] GitHub CI: dependency install, TypeScript typecheck, ESLint and production build passed on current branch head.\n- [ ] Apply and validate all migrations in the dedicated MFA Supabase project; run database security and permission tests.

### Phase 2 — Public website
- [x] Responsive home page.
- [x] About and Services.
- [x] Global Agent Directory initial page (verified-only query and empty state).
- [x] Become an Agent.
- [x] Business Partners and Advertising.
- [x] Help and Complaints, Contact.
- [x] Preliminary Privacy and Terms pages.
- [ ] Complete accessibility and mobile/browser QA.
- [ ] Replace preliminary legal copy after qualified review.

### Phase 3 — Agent onboarding and directory
- [x] Individual/business application form.
- [x] Account sign-up and email-confirmation callback.
- [x] Database trigger creates pending agent application from signup metadata.
- [x] Public directory query exposes verified profiles only.
- [ ] Logo/profile image upload with storage bucket policies and validation.
- [ ] Directory filters: country, region/city, service, payment network, language and online status.
- [ ] Profile editing and application status timeline.

### Phase 4 — Verification, branding and portals
- [x] Agent Portal protected server route foundation.
- [x] Super Admin route protected by role and AAL2 check.
- [x] Initial dashboard counts.
- [x] Verification event table.
- [x] Admin approve/reject/suspend/request-information workflow (RPC, server action, UI; migration pending live application).
- [x] Capture decision reasons, internal evidence references, verification events and audit-log entries in the review RPC.\n- [ ] Evidence file storage and complete audit review UI.
- [ ] Trust Badge UI and profile branding.
- [ ] Agent requests, transaction references, commission statements, support and security settings.
- [ ] Country/Regional Manager scoped permissions and tests.

### Phase 5 — Additive V1.1 modules
1. [ ] Agent Network & Listing completion.
2. [ ] Agent Branding & Advertising approval workflow and publication schedule.
3. [ ] Fee & Commission Engine with configurable versioned rules and idempotency.
4. [ ] Multi-partner profiles, contract approval, scoped credentials, usage limits and API logs.
5. [ ] Support & Complaints workflow with New, Assigned, In Progress, Resolved and Closed states.
6. [ ] Escrow & Agent Guarantee Engine in sandbox/test mode only, with separate agent statements, available/reserved/disputed/released classifications, reconciliation, limits and dispute/refund workflows.

### Phase 6 — Partner API and CFG readiness
- [ ] Define partner-agnostic API contracts.
- [ ] Partner authentication, scopes, signature verification, rate limits, idempotency and logs.
- [ ] Transaction references and status responses only.
- [ ] CFG remains source of truth for its business, wallet, balances, ledger and payment confirmation.
- [ ] No direct MFA-to-CFG database or ledger access.
- [ ] Sandbox tests for unauthorized access, duplicate webhook, timeout, reversal, refund and dispute.

### Phase 7 — Security, quality and handover
- [ ] Role permissions and partner data-isolation tests.
- [ ] Agent verification lifecycle and Trust Badge tests.
- [ ] Upload/input validation and rate-limit tests.
- [ ] Idempotency and rule-version history tests.
- [ ] Secret scanning.\n- [ ] Triage 16 moderate dependency vulnerabilities reported during `npm install`; review advisories before applying upgrades.
- [ ] Backup/restore plan and restore test.
- [ ] Run automated tests, lint/typecheck and build.
- [ ] Publish remaining-work, security and test reports.
- [ ] Review preview only; no production deployment or merge.

## 4. Guarantee and bank-account controls

Preferred arrangement is an approved third-party bank/escrow structure. A separate designated MFA bank account may be evaluated only if escrow is unavailable and the bank and legal adviser approve it. It must not be an ordinary operating account. Deposits must remain segregated, not fund normal expenses and not be mixed with CFG/CFGG or another partner's funds.

Until legal and banking approval is documented, keep guarantee functions in sandbox, publish no real deposit instructions, accept no real deposits and grant no transaction permissions requiring a guarantee. Screenshots alone are not final proof of deposit.

## 5. Decisions requiring owner confirmation

- First registration/operating countries and pilot regions.
- Initial services to be offered.
- Final company name/domain after legal and trademark checks.
- Approved payment providers and agreements.
- Fees, commissions, advertising prices and transaction limits.
- Banking/legal structure for agent guarantees.
- Final hosting and production deployment arrangements.

## 6. Current implementation status

- Audit and plan: committed.
- Next.js + Supabase foundation: committed.
- Public pages and initial agent application: committed.
- Initial database migration and RLS: committed, not yet applied to a live Supabase project.
- Agent/Admin portal shells and Super Admin verification workflow: committed; app typecheck/lint/build passed; live Supabase migration and authenticated runtime validation pending.
- CI: successful on current branch head (run `41294653176`); dependency install, typecheck, lint and production build passed.
- Production deployment and merge: not performed.
