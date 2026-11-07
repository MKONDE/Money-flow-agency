import Link from "next/link";
import {redirect} from "next/navigation";
import {createClient} from "@/lib/supabase/server";
import AgentRequests from "./AgentRequests";
import AgentLocationForm from "./AgentLocationForm";
import AgentCapitalDeclarationForm from "./AgentCapitalDeclarationForm";
import AgentTrackedTransactions from "./AgentTrackedTransactions";
import AgentPresenceToggle from "./AgentPresenceToggle";
import AgentBrandingForm from "./AgentBrandingForm";
import AgentCfgSupplyForm from "./AgentCfgSupplyForm";
import AgentReferralPanel from "./AgentReferralPanel";
export const dynamic="force-dynamic";
export default async function AgentPortalPage(){
 if(!process.env.NEXT_PUBLIC_SUPABASE_URL||!process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY)redirect("/login?message=setup_required");
 const supabase=await createClient();const {data:{user}}=await supabase.auth.getUser();if(!user)redirect("/login");
 const {data:agent}=await supabase.from("agent_profiles").select("id,brand_name,status,description,country_code,region,city,services,transaction_enabled,is_online,public_contact_consent,logo_url,referral_code").eq("user_id",user.id).maybeSingle();if(!agent)redirect("/become-agent");
 const [{data:location},{data:capital},{data:guarantees},{data:trust},{data:requests},{data:transactions},{data:commissions},{data:cfgSupply},{data:referralEntries}]=await Promise.all([
  supabase.from("agent_location_profiles").select("country_code,region,district,city,ward,neighbourhood,service_address,location_type,service_areas,public_listing_consent,review_status").eq("agent_id",agent.id).maybeSingle(),
  supabase.from("mfa_agent_capital_profiles").select("currency,declared_capital,declared_transaction_float,declaration_notes").eq("agent_id",agent.id).maybeSingle(),
  supabase.from("mfa_agent_guarantees").select("id,guarantee_type,issuer_name,guarantee_reference,amount,currency,verification_status,verification_reason,valid_until").eq("agent_id",agent.id).order("created_at",{ascending:false}),
  supabase.from("mfa_agent_trust_badges").select("trust_level,badge_status,valid_until").eq("agent_id",agent.id).maybeSingle(),
  supabase.from("service_requests").select("id,reference_code,service_type,request_mode,request_status,amount,currency,customer_note,created_at").eq("assigned_agent_id",agent.id).order("created_at",{ascending:false}).limit(50),
  supabase.from("mfa_transactions").select("id,reference_code,status,amount,currency,service_code,payment_network,customer_note,created_at,evidence_reference").eq("agent_id",agent.id).order("created_at",{ascending:false}).limit(50),
  supabase.from("mfa_commission_entries").select("id,transaction_id,commission_pool,agent_commission,company_revenue,operations_risk_reserve,currency,calculated_at,rule_snapshot").eq("agent_id",agent.id).order("calculated_at",{ascending:false}).limit(50),
  supabase.from("mfa_agent_cfg_supply").select("claimed_supply_usd,verified_supply_usd,evidence_reference,verification_status,verification_reason,last_checked_at").eq("agent_id",agent.id).maybeSingle(),
  supabase.from("mfa_referral_commission_entries").select("id,currency,referral_commission,company_revenue,company_share_reward_pct,referred_agent_id,calculated_at,eligible_until").eq("referrer_agent_id",agent.id).order("calculated_at",{ascending:false}).limit(100)
 ]);
 const commissionTotals=Object.entries((commissions??[]).reduce((acc,x)=>{acc[x.currency]=(acc[x.currency]??0)+Number(x.agent_commission);return acc;},{} as Record<string,number>));
 return <section className="content-section"><div className="container">
  <div className="section-kicker">AGENT PORTAL</div><h1 style={{fontSize:42}}>Welcome, {agent.brand_name}</h1><p className="form-note">Your private agent workspace.</p>
  <div className="portal-grid" style={{marginTop:30}}>
   <div className="portal-tile"><strong>Application status</strong><span>{agent.status.toUpperCase()} — public listing requires MFA approval.</span></div>
   <div className="portal-tile"><strong>Trust classification</strong><span>{(trust?.trust_level??"independent_agent").replaceAll("_"," ").toUpperCase()} · {(trust?.badge_status??"active").toUpperCase()}</span></div>
   <div className="portal-tile"><strong>Transaction permissions</strong><span>Tracking-only V1. No real money movement, custody or payouts.</span></div>
  </div>
  <div style={{marginTop:16}}><AgentPresenceToggle agentId={agent.id} initialOnline={agent.is_online} initialContactConsent={agent.public_contact_consent}/></div>
  <div className="content-card" style={{marginTop:22}}><h2 style={{fontSize:24}}>CFG Supply & Agent Activation</h2><p className="form-note">Minimum verified CFG Supply: USD 50 equivalent. Your account becomes operationally ACTIVE only after identity verification and MFA confirmation of the minimum supply.</p><AgentCfgSupplyForm initial={cfgSupply??null} agentStatus={agent.status}/></div>
  <div className="content-card" style={{marginTop:22}}><h2 style={{fontSize:24}}>Invite Agents & Referral Commission</h2><AgentReferralPanel code={agent.referral_code??"Pending code"} entries={referralEntries??[]}/></div>
  <div className="content-card" style={{marginTop:22}}><h2 style={{fontSize:24}}>Capital, float and guarantee declarations</h2><AgentCapitalDeclarationForm agentId={agent.id} initialCapital={capital??null} initialGuarantees={guarantees??[]}/></div>
  <div className="content-card" style={{marginTop:22}}><h2 style={{fontSize:24}}>Tracked transactions assigned to you</h2><p className="form-note">You may advance only the permitted tracking statuses. You cannot confirm payments or transfer funds.</p><AgentTrackedTransactions initial={transactions??[]}/></div>
  <div className="content-card" style={{marginTop:22}}><h2 style={{fontSize:24}}>Commission calculation history</h2><p className="form-note">Calculation records only. These amounts are not a payable balance and cannot be withdrawn.</p>{commissionTotals.map(([currency,total])=><div className="portal-tile" key={currency}><strong>Calculated agent commission · {currency}</strong><span style={{fontSize:24,fontWeight:800}}>{total.toLocaleString(undefined,{maximumFractionDigits:2})}</span></div>)}{(commissions??[]).map(x=><p className="form-note" key={x.id}>{x.currency} {Number(x.agent_commission).toLocaleString()} · {new Date(x.calculated_at).toLocaleString()}</p>)}</div>
  <div className="content-card" style={{marginTop:22}}><h2 style={{fontSize:24}}>Your service requests</h2><p className="form-note">Requests assigned to your agent account. These remain demo service requests.</p><AgentRequests requests={requests??[]}/></div>
  <div className="content-card" style={{marginTop:22}}><h2 style={{fontSize:24}}>Agent location and service coverage</h2><AgentLocationForm agentId={agent.id} initial={location??null}/></div>
  <div className="content-card" style={{marginTop:22}}><h2 style={{fontSize:24}}>Business branding</h2><AgentBrandingForm agentId={agent.id} initialLogo={agent.logo_url}/></div>
  <div className="content-card" style={{marginTop:22}}><h2 style={{fontSize:24}}>Your profile</h2><p>{agent.description||"Add a description to your profile."}</p><p className="form-note">Services: {(agent.services??[]).join(" · ")||"Not yet selected"}</p><Link className="text-link" href="/help">Get support →</Link></div>
 </div></section>;
}
