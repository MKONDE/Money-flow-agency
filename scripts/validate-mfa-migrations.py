#!/usr/bin/env python3
"""Static validation for MFA PostgreSQL migrations; never connects to a database."""
from pathlib import Path
import re
import sys

try:
    from pglast import parse_sql
except ImportError as exc:
    raise SystemExit("Missing pglast. Install it with: python -m pip install pglast") from exc

root = Path("supabase/migrations")
files = sorted(root.glob("*.sql"))
if not files:
    raise SystemExit("No SQL migrations found.")

errors = []
for path in files:
    sql = path.read_text(encoding="utf-8")
    try:
        parse_sql(sql)
    except Exception as exc:
        errors.append(f"{path}: PostgreSQL parse error: {exc}")

def require(path: str, patterns: dict[str, str]) -> None:
    target = Path(path)
    if not target.exists():
        errors.append(f"{target}: required safety migration is missing")
        return
    content = re.sub(r"\s+", " ", target.read_text(encoding="utf-8")).lower()
    for label, pattern in patterns.items():
        if not re.search(pattern, content, flags=re.IGNORECASE):
            errors.append(f"{target}: missing safety invariant: {label}")

require(
    "supabase/migrations/20261101130000_mfa_agent_trust_capital_commission_tables.sql",
    {
        "transactions remain simulation-only": r"simulation_only\s+boolean[^,;]*check\s*\(\s*simulation_only\s*=\s*true\s*\)",
        "escrow cannot hold funds": r"funds_held\s+boolean[^,;]*check\s*\(\s*funds_held\s*=\s*false\s*\)",
        "escrow cannot execute release": r"release_executed\s+boolean[^,;]*check\s*\(\s*release_executed\s*=\s*false\s*\)",
        "commissions are non-payable": r"payable\s+boolean[^,;]*check\s*\(\s*payable\s*=\s*false\s*\)",
    },
)
require(
    "supabase/migrations/20261101133000_mfa_public_directory_online_presence.sql",
    {
        "contact consent defaults to private": r"public_contact_consent\s+boolean\s+not\s+null\s+default\s+false",
        "phone publication requires consent": r"case\s+when\s+new\.public_contact_consent\s+then\s+new\.phone\s+else\s+null\s+end",
        "email publication requires consent": r"case\s+when\s+new\.public_contact_consent\s+then\s+new\.public_email\s+else\s+null\s+end",
    },
)
require(
    "supabase/migrations/20261101120000_mfa_agent_verification_workflow.sql",
    {
        "agent approval requires AAL2": r"auth\.jwt\(\).*aal.*aal2",
        "transaction execution remains disabled on approval": r"transaction_enabled\s*=\s*false",
    },
)

require(
    "supabase/migrations/20261101135000_mfa_agent_cfg_supply_activation_gate.sql",
    {
        "CFG Supply verification cannot approve less than USD 50": r"p_verified_supply_usd\\s*<\\s*50",
        "only verified USD 50 supply makes an agent active": r"verified_supply_usd\\s*>=\\s*50",
        "agent transaction assignment requires verified minimum supply": r"mfa_agent_minimum_cfg_supply_gate",
        "CFG Supply review requires AAL2": r"auth\\.jwt\\(\\).*aal.*aal2",
        "CFG Supply evidence is reviewed through controlled RPC": r"mfa_review_agent_cfg_supply",
        "agent submission is recorded as pending": r"'pending'",
    },
)

require(
    "supabase/migrations/20261101136000_mfa_direct_agent_referral_commission_v1.sql",
    {
        "referral default is 10 percent of company share": r"company_share_reward_pct\\s+numeric\\(7,4\\)\\s+not\\s+null\\s+default\\s+10",
        "referral default duration is 12 months": r"duration_months\\s+integer\\s+not\\s+null\\s+default\\s+12",
        "referral calculations are funded from company share only": r"'funding_source'\\s*,\\s*'mfa_company_share_only'",
        "referral entries remain non-payable": r"payable\\s+boolean\\s+not\\s+null\\s+default\\s+false\\s+check\\s*\\(\\s*payable\\s*=\\s*false",
        "AAL2 admin RPC protects referral settings": r"mfa_update_referral_commission_settings",
        "direct referral attribution is captured on agent signup": r"zz_mfa_capture_agent_referral",
    },
)

if errors:
    print("MFA migration validation FAILED:")
    for error in errors:
        print(f" - {error}")
    raise SystemExit(1)

print(f"MFA migration validation passed: parsed {len(files)} SQL migration files; critical safety invariants verified.")
