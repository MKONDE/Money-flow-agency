# Money Flow Agency (MFA)

Independent agent network and business services platform.

## Project rules

- MFA is an independent platform and can serve multiple partners.
- Cashflow Gate (CFG) is one partner, not the owner of MFA.
- Keep MFA repository, Supabase project, authentication, records, secrets and deployment separate from CFG, Jakay Pesa, Jakay Group and Maharoos Mini.
- Never write to CFG/CFGG wallets, balances or ledgers.
- V1.1 is additive to the original Master Blueprint V1.
- Real deposits, withdrawals, transfers, customer wallets, custody, crypto exchange, payment execution and guarantee collection remain disabled.
- Work on `feature/mfa-foundation-audit-v1`; do not merge into `main` or deploy production without owner approval.

## Technology

- Next.js App Router (TypeScript)
- Supabase PostgreSQL and Auth
- Supabase SSR cookie-based session integration
- Vercel preview hosting (not configured or deployed by this foundation)

## Local setup

1. Install Node.js 20.9 or newer.
2. Create a **new, dedicated Supabase project for MFA**. Do not reuse credentials from any other project.
3. In the MFA Supabase SQL Editor, apply `supabase/migrations/202610310001_mfa_foundation.sql`.
4. Copy `.env.example` to `.env.local` and enter the MFA project's Project URL and Publishable Key.
5. Install dependencies with `npm install`.
6. Run `npm run dev` and open `http://localhost:3000`.

## Environment variables

- `NEXT_PUBLIC_SUPABASE_URL`: MFA Supabase project URL.
- `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`: MFA Supabase publishable key.

No service-role key is required by the public website. Never put a service-role key in a `NEXT_PUBLIC_*` variable or commit secrets to Git.

## Initial routes

- `/` — public home page
- `/about`, `/services`, `/partners`, `/advertising`
- `/agents` — public directory (only verified agents are displayed)
- `/become-agent` — account creation and agent application
- `/login` — sign-in
- `/agent` — authenticated agent portal foundation
- `/admin` — Super Admin foundation; requires AAL2 MFA
- `/help`, `/contact`, `/privacy`, `/terms`

## Database and security notes

The initial migration creates profiles, agent profiles, verification events, business partners, support tickets and audit logs. Row Level Security is enabled. New users receive the `customer` role by default; users cannot promote themselves. Agent applications are created by a database trigger and remain pending until an authorized review workflow is implemented.

The first portal iteration intentionally limits administrative access to a Super Admin with an AAL2 session. Country/Regional Manager scoping is not enabled until its policies are implemented and tested. The agent portal currently shows the applicant's own application record only.

The directory exposes verified profiles only. Verification evidence is not public. Listing or a Trust Badge is not a guarantee of a transaction or financial outcome.

## Current limitations

- The Supabase project has not been provisioned or connected by this repository change.
- Logo/profile-image upload awaits a dedicated storage bucket and upload validation.
- Admin review actions and role provisioning require a controlled server-side workflow.
- Agent search filters, service requests, partner API, fee/commission engine, advertising approvals and guarantee workflows are not complete.
- MFA enrollment UI, support case submission, backups/restore and full automated security tests remain to be completed.
- Privacy, Terms, compliance and operational policies require owner and qualified legal review before production.

## Validation

Run `npm run typecheck`, `npm run lint` and `npm run build` after installing dependencies and configuring the environment. This branch is not a production release.
