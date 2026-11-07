import Link from "next/link";
import {redirect} from "next/navigation";
import {createClient} from "@/lib/supabase/server";
import AgentTrustCapitalWorkspace from "./AgentTrustCapitalWorkspace";
export const dynamic="force-dynamic";
export default async function AgentTrustCapitalAdminPage(){
 if(!process.env.NEXT_PUBLIC_SUPABASE_URL||!process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY)redirect("/login?message=setup_required");
 const sb=await createClient();const {data:{user}}=await sb.auth.getUser();if(!user)redirect("/login");
 const {data:profile}=await sb.from("profiles").select("role").eq("id",user.id).maybeSingle();if(profile?.role!=="super_admin")redirect("/agent");
 const {data:aal}=await sb.auth.mfa.getAuthenticatorAssuranceLevel();if(aal?.currentLevel!=="aal2")redirect("/admin");
 const [
  agentsResult,badgesResult,trustHistoryResult,capitalResult,guaranteesResult,tiersResult,transactionsResult,statusHistoryResult,exposuresResult,
  disputesResult,rulesResult,entriesResult,countriesResult,partnersResult,escrowsResult,auditResult
 ]=await Promise.all([
  sb.from("agent_profiles").select("id,brand_name,status,country_code,city,region").order("brand_name").limit(500),
  sb.from("mfa_agent_trust_badges").select("agent_id,trust_level,badge_status,reason,valid_until"),
  sb.from("mfa_agent_trust_history").select("id,agent_id,previous_level,new_level,badge_status,reason,actor_id,created_at").order("created_at",{ascending:false}).limit(200),
  sb.from("mfa_agent_capital_profiles").select("agent_id,currency,declared_capital,declared_transaction_float,declaration_notes"),
  sb.from("mfa_agent_guarantees").select("id,agent_id,issuer_name,guarantee_reference,amount,currency,verification_status,verification_reason,valid_until").order("created_at",{ascending:false}).limit(200),
  sb.from("mfa_capital_tiers").select("id,tier_code,tier_name,currency,minimum_declared_capital,minimum_verified_guarantee,max_per_transaction,max_pending_exposure,max_daily_volume,max_monthly_volume,enabled").order("currency"),
  sb.from("mfa_transactions").select("id,reference_code,requester_id,agent_id,partner_id,service_code,country_code,currency,payment_network,amount,commissionable_amount,status,created_at,customer_reference,agent_reference,partner_reference,evidence_reference,customer_note").order("created_at",{ascending:false}).limit(200),
  sb.from("mfa_transaction_status_history").select("id,transaction_id,previous_status,new_status,actor_id,actor_role,note,created_at").order("created_at",{ascending:false}).limit(500),
  sb.from("mfa_agent_exposure_summary").select("agent_id,currency,pending_exposure,daily_volume,monthly_volume,pending_transaction_count"),
  sb.from("mfa_transaction_disputes").select("id,transaction_id,reason_code,description,dispute_status,resolution_note,created_at").order("created_at",{ascending:false}).limit(100),
  sb.from("mfa_commission_rules").select("id,rule_name,scope_type,scope_key,currency,agent_share_pct,company_share_pct,operations_reserve_pct,minimum_commission_pool,maximum_commission_pool,effective_from,enabled").order("effective_from",{ascending:false}),
  sb.from("mfa_commission_entries").select("id,transaction_id,agent_id,partner_id,country_code,service_code,currency,commission_pool,agent_commission,company_revenue,operations_risk_reserve,calculated_at,rule_snapshot").order("calculated_at",{ascending:false}).limit(500),
  sb.from("mfa_country_settings").select("country_code,country_name,default_currency,supported_currencies,enabled").order("country_name"),
  sb.from("business_partners").select("id,display_name,legal_name,contract_status,country_code").order("display_name").limit(200),
  sb.from("mfa_escrow_workflows").select("id,transaction_id,workflow_status,release_conditions,customer_confirmed_at,dispute_status,funds_held,release_executed").order("created_at",{ascending:false}).limit(100),
  sb.from("mfa_financial_audit_events").select("id,table_name,record_id,operation,created_at").order("created_at",{ascending:false}).limit(100)
 ]);
 const errors=[agentsResult.error,badgesResult.error,trustHistoryResult.error,capitalResult.error,guaranteesResult.error,tiersResult.error,transactionsResult.error,statusHistoryResult.error,exposuresResult.error,disputesResult.error,rulesResult.error,entriesResult.error,countriesResult.error,partnersResult.error,escrowsResult.error,auditResult.error].filter(Boolean);
 return <section className="content-section"><div className="container">
  <div className="section-kicker">MFA SUPER ADMIN · AAL2</div><h1 style={{fontSize:42}}>Agent Trust, Capital & Commission</h1>
  <p className="form-note">This control center manages agent trust, declared capital, documentary guarantees, tracking-only transaction states and commission calculations. It cannot receive, hold, release or transfer customer funds.</p>
  <p><Link className="text-link" href="/admin">← Back to Admin Workspace</Link> · <Link className="text-link" href="/admin/agent-supply">Review Agent CFG Supply →</Link></p>
  {errors.length>0&&<p className="form-note">Some data tables could not be read. Confirm all MFA migrations are applied and inspect RLS policies. Workspace sections may be incomplete.</p>}
  <AgentTrustCapitalWorkspace agents={agentsResult.data??[]} badges={badgesResult.data??[]} trustHistory={trustHistoryResult.data??[]} statusHistory={statusHistoryResult.data??[]} exposures={exposuresResult.data??[]} capital={capitalResult.data??[]} guarantees={guaranteesResult.data??[]} tiers={tiersResult.data??[]} transactions={transactionsResult.data??[]} disputes={disputesResult.data??[]} rules={rulesResult.data??[]} entries={entriesResult.data??[]} countries={countriesResult.data??[]} partners={partnersResult.data??[]} escrows={escrowsResult.data??[]} audit={auditResult.data??[]}/>
 </div></section>;
}
