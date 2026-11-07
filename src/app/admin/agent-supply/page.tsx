import Link from "next/link";
import {redirect} from "next/navigation";
import {createClient} from "@/lib/supabase/server";
import AgentCfgSupplyReview from "./AgentCfgSupplyReview";
export const dynamic="force-dynamic";
export default async function AgentCfgSupplyAdminPage(){
 if(!process.env.NEXT_PUBLIC_SUPABASE_URL||!process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY)redirect("/login?message=setup_required");
 const sb=await createClient();const {data:{user}}=await sb.auth.getUser();if(!user)redirect("/login");
 const {data:profile}=await sb.from("profiles").select("role").eq("id",user.id).maybeSingle();if(profile?.role!=="super_admin")redirect("/agent");
 const {data:aal}=await sb.auth.mfa.getAuthenticatorAssuranceLevel();if(aal?.currentLevel!=="aal2")redirect("/admin");
 const {data:supplies,error}=await sb.from("mfa_agent_cfg_supply").select("agent_id,claimed_supply_usd,verified_supply_usd,evidence_reference,verification_status,verification_reason,updated_at").order("updated_at",{ascending:false}).limit(300);
 const ids=(supplies??[]).map(x=>x.agent_id);
 const {data:agents}=ids.length?await sb.from("agent_profiles").select("id,brand_name,country_code,city,status").in("id",ids):{data:[]};
 const byId=new Map((agents??[]).map(a=>[a.id,a]));
 const rows=(supplies??[]).map(s=>({agent_id:s.agent_id,claimed_supply_usd:s.claimed_supply_usd,verified_supply_usd:s.verified_supply_usd,evidence_reference:s.evidence_reference,verification_status:s.verification_status,verification_reason:s.verification_reason,updated_at:s.updated_at,agent_name:byId.get(s.agent_id)?.brand_name??"Unknown agent",country_code:byId.get(s.agent_id)?.country_code??"",city:byId.get(s.agent_id)?.city??null,agent_status:byId.get(s.agent_id)?.status??"unknown"}));
 return <section className="content-section"><div className="container"><div className="section-kicker">MFA SUPER ADMIN · AAL2</div><h1 style={{fontSize:42}}>Agent CFG Supply Verification</h1><p className="form-note">Only verify supply after checking the external CFG source/reference. The minimum is USD 50 equivalent. This review activates the MFA agent eligibility gate only; it does not enable money movement, custody, escrow release or payouts.</p><p><Link className="text-link" href="/admin/agent-trust">← Agent Trust & Capital</Link> · <Link className="text-link" href="/admin">Admin Workspace</Link></p>{error&&<p className="form-note">Could not load CFG Supply submissions: {error.message}</p>}<AgentCfgSupplyReview initial={rows}/></div></section>;
}
