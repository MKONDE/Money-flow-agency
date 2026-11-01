import Link from "next/link";
import {createClient} from "@/lib/supabase/server";
type Agent={id:string;brand_name:string;description:string|null;country_code:string;region:string|null;city:string|null;services:string[]|null;languages:string[]|null;logo_url:string|null;is_online:boolean;payment_networks:string[]|null;public_phone:string|null;public_email:string|null};
type Badge={agent_id:string;trust_level:string;badge_status:string;valid_until:string|null};
export const dynamic="force-dynamic";
export default async function AgentsPage({searchParams}:{searchParams:Promise<{country?:string;city?:string;q?:string}>}){
 const params=await searchParams;let agents:Agent[]=[];let badges:Badge[]=[];
 const configured=Boolean(process.env.NEXT_PUBLIC_SUPABASE_URL&&process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY);
 if(configured){try{
  const supabase=await createClient();let query=supabase.from("public_agent_directory").select("id,brand_name,description,country_code,region,city,services,languages,logo_url,is_online,payment_networks,public_phone,public_email").order("brand_name").limit(100);
  if(params.country)query=query.eq("country_code",params.country.trim().toUpperCase());
  if(params.city)query=query.ilike("city","%"+params.city.trim()+"%");
  if(params.q)query=query.ilike("brand_name","%"+params.q.trim()+"%");
  const {data}=await query;agents=(data??[]) as Agent[];
  if(agents.length){const {data:trust}=await supabase.from("mfa_agent_trust_badges").select("agent_id,trust_level,badge_status,valid_until").in("agent_id",agents.map(a=>a.id));badges=(trust??[]) as Badge[];}
 }catch{}}
 const badgeMap=new Map(badges.map(b=>[b.agent_id,b]));
 return <><section className="page-hero"><div className="container"><div className="section-kicker">GLOBAL AGENT NETWORK</div><h1>Find local support.<br/><em>Connect with an agent.</em></h1><p>Search independent agent profiles by country, city and business name. Public contact information appears only when the agent has opted in.</p></div></section>
 <section className="content-section"><div className="container">
  <form method="get" className="content-card" style={{marginBottom:24}}><div className="form-grid">
   <div className="field"><label htmlFor="q">Agent or business name</label><input id="q" name="q" defaultValue={params.q??""} placeholder="Search by name"/></div>
   <div className="field"><label htmlFor="country">Country code</label><input id="country" name="country" maxLength={2} defaultValue={params.country??""} placeholder="TZ"/></div>
   <div className="field"><label htmlFor="city">City</label><input id="city" name="city" defaultValue={params.city??""} placeholder="Tabora"/></div>
  </div><button className="button button-small" style={{marginTop:14}}>Search agents</button></form>
  {agents.length?<div className="pillar-grid">{agents.map(a=>{const b=badgeMap.get(a.id);const label=b?.badge_status==="active"&&(!b.valid_until||new Date(b.valid_until)>new Date())?b.trust_level:"verified_agent";return <article className="pillar-card" key={a.id}>
   <div style={{display:"flex",justifyContent:"space-between",gap:8,flexWrap:"wrap"}}><span className="badge-status">{label.replaceAll("_"," ").toUpperCase()}</span><span className="form-note">{a.is_online?"● ONLINE":"○ OFFLINE"}</span></div>
   <h3 style={{marginTop:22}}>{a.brand_name}</h3><p>{[a.city,a.region,a.country_code].filter(Boolean).join(", ")}</p><p>{a.description}</p>
   <div className="form-note">{(a.services??[]).join(" · ")}</div>
   {(a.payment_networks??[]).length>0&&<p className="form-note">Networks: {(a.payment_networks??[]).join(" · ")}</p>}
   {a.public_phone&&<p className="form-note">Phone: {a.public_phone}</p>}{a.public_email&&<p className="form-note">Email: {a.public_email}</p>}
  </article>})}</div>:<div className="empty-state"><div className="empty-state-mark">◎</div><h2>No matching public agents yet</h2><p>Approved agent listings will appear here. Try a different city or country, or apply to join the network.</p><Link className="button" href="/become-agent">Apply to become an agent <span>↗</span></Link></div>}
 </div></section></>;
}
