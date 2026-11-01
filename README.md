# Money Flow Agency (MFA)

Independent global agent network and multi-partner business services platform.

## Non-negotiable project boundaries

- MFA is an independent platform. Cashflow Gate (CFG) is one potential business partner, not the owner of MFA.
- Keep the MFA repository, Supabase project, authentication, records, credentials and deployment separate from CFG, Jakay Pesa, Jakay Group and Maharoos Mini.
- Never connect MFA to CFG/CFGG wallets, balances or ledgers.
- MFA V1 is not a bank, cryptocurrency, token, digital currency or customer wallet provider.
- No real customer deposits, withdrawals, transfers, payment execution, funds custody, escrow holding, crypto exchange or guarantee collection.
- Agent capital and float are declarations only. Guarantee records are documentary references, not money collected by MFA.
- Transaction records are tracking-only and are database-constrained to \`simulation_only = true\`.
- Escrow metadata is readiness-only and database-constrained to \`funds_held = false\` and \`release_executed = false\`.
- Commission entries are immutable calculation snapshots and database-constrained to \`payable = false\`.
- Never commit \`.env\` files or expose service-role/secret keys.
- Work only on feature branches. Never commit directly to \`main\`, merge or deploy production without owner approval.

## Technology

- Next.js App Router 16 + TypeScript
- Supabase PostgreSQL, Auth and Row Level Security
- Supabase SSR cookie-based sessions
- GitHub Actions for typecheck, lint, safety-guard checks and production build
- Vercel preview may be configured after review; no production deployment is authorized by this repository change.

## Dedicated Supabase project

Use only the separately provisioned Supabase project named **money-flow-agency**. Never reuse CFG, Jakay, Maharoos Mini or another project's credentials.

**Schema-drift warning:** the connected MFA database has existing operational tables (including service request, partner and receipt records) that are not all represented in the tracked migration history. Before applying this branch's migrations to any shared/live database, reconcile the live schema with every migration and preserve existing data. Do not drop, recreate or overwrite existing tables to resolve drift.

## Local setup

1. Install Node.js 20.9 or newer.
2. Create a dedicated MFA Supabase project and confirm its project name before using credentials.
3. Review the current database schema and migration history. Resolve schema drift in a staging copy first.
4. Apply all files in \`supabase/migrations/\` in filename order, oldest to newest, to a dedicated MFA test/staging database.
5. Copy \`.env.example\` to \`.env.local\` and enter only the MFA Project URL and Publishable Key.
6. Run \`npm install\`.
7. Run \`npm run typecheck\`, \`npm run lint\`, and \`npm run build\`.
8. After migrations are applied to a test database, run \`supabase/tests/mfa_agent_trust_capital_commission_v1.sql\` in the SQL editor.
9. Run \`npm run dev\` and open \`http://localhost:3000\`.

## Environment variables

- \`NEXT_PUBLIC_SUPABASE_URL\`: MFA Supabase project URL.
- \`NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY\`: MFA Supabase publishable key.

The public website does not require a service-role key. Never expose a service-role/secret key in a \`NEXT_PUBLIC_*\` variable or commit secrets to Git.

## Routes

### Public
- \`/\`, \`/about\`, \`/services\`, \`/partners\`, \`/advertising\`
- \`/agents\` — searchable verified-agent directory with online status, supported networks and opt-in public contacts
- \`/become-agent\` — account creation and agent application
- \`/transactions\` — authenticated customer tracking-only transaction requests and disputes
- \`/help\`, \`/contact\`, \`/privacy\`, \`/terms\`

### Authenticated
- \`/login\`
- \`/agent\` — agent profile, presence, capital/float declarations, guarantee references, tracking queue and commission calculation history
- \`/admin\` — Super Admin workspace; requires AAL2
- \`/admin/agent-trust\` — Super Admin trust, capital, guarantees, tiers, transaction monitoring, disputes, escrow-ready metadata, commission rules and revenue reporting; requires AAL2

## Agent Trust, Capital & Commission Engine V1

- Agent trust classifications: Independent, Verified, Capital-Backed, Premium and Strategic. Higher trust levels require a verified agent; Capital-Backed additionally requires declared capital and a separately verified guarantee.
- Capital tiers are currency-specific and admin-configurable. No arbitrary transaction limits are seeded. An agent cannot be assigned a tracked transaction until a matching tier, capital declaration and verified guarantee exist.
- Declared transaction float is stored separately from declared capital and is not money held by MFA.
- Transactions have unique references, customer/agent/partner references, country, currency, payment network, amount, evidence reference, status and immutable status history.
- Customer transaction creation is limited to 20 tracking requests per authenticated user per hour in V1.
- Commission uses an explicit \`commissionable_amount\` (service-fee pool) and never automatically treats the transaction principal as commission.
- Default split: Agent 70%, MFA company 20%, Operations & Risk Reserve 10%. More-specific country/service/agent/partner rules override broader rules. Historical entries preserve the rule snapshot used at completion.
- Commission calculations are non-payable accrual records; no wallet, withdrawal or payout feature exists.
- Escrow-ready records store release conditions and customer confirmation only. No provider is connected and database checks prevent funds being held or released.

## Security controls

- RLS is enabled on every new public-schema table.
- Admin write policies require the Super Admin database role and AAL2.
- Agent permissions are limited to owned declarations, guarantee submissions and assigned transaction progress.
- Customer permissions are limited to owned tracking records and permitted disputes/confirmations.
- Partner owners can read their assigned transaction references only.
- Status history, dispute events, trust history, commission entries and financial audit events are append-only.
- Trigger functions live in the non-exposed \`private\` schema, with execute privileges revoked from public API roles.
- Agent assignment checks capital tiers, verified guarantees, per-transaction limits, pending exposure, daily volume and monthly volume.
- AAL2 is required for administrative partner, trust, capital, transaction, dispute, escrow and commission-rule changes.

## Known limitations and deployment gates

- The branch migrations have not been applied to the live Supabase project. The live database has schema drift that must be reconciled first.
- The SQL smoke-test script is committed but has not yet been executed against a migrated staging database.
- Browser/end-to-end tests, adversarial RLS tests, concurrent limit tests and restore tests remain pending.
- Logo/profile image uploads require a dedicated Storage bucket and explicit upload validation/policies.
- Partner API credentials, signed webhooks and provider integration are not implemented.
- Real escrow provider support is not connected; no money may be held or released.
- Capital tier values must be configured by the owner before assigning agents; no currency conversion is performed.
- The 20-per-hour transaction creation throttle is a V1 guardrail and should be reviewed before a public-scale launch.
- Backups, point-in-time recovery and restore drills must be configured and tested in Supabase before production.
- Legal, privacy, financial-services and country-specific compliance review is required before any live financial service.
- No production deployment, merge to main, real payment, deposit, withdrawal, escrow, custody or transfer is authorized.

## Validation

GitHub Actions runs on feature branches and pull requests to main. It runs dependency installation, tracking-only SQL safety assertions, TypeScript typecheck, ESLint and production build. Database smoke tests require the dedicated MFA test/staging database and must be run separately.
