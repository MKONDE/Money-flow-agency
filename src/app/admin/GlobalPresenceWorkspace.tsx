"use client";
import { useState } from "react";
import { createClient } from "@/lib/supabase/client";

type Rep = {id:string;country_code:string;display_name:string;title:string;public_city:string|null;public_phone:string|null;public_email:string|null;verification_status:string;status:string;show_publicly:boolean};
type Office = {id:string;country_code:string;office_name:string;office_type:string;city:string|null;public_address:string|null;public_phone:string|null;verification_status:string;status:string;show_publicly:boolean};
type AgentLocation = {id:string;agent_id:string;country_code:string;region:string|null;district:string|null;city:string|null;ward:string|null;neighbourhood:string|null;service_address:string|null;location_type:string;service_areas:string[];public_listing_consent:boolean;review_status:string};
export default function GlobalPresenceWorkspace({representatives,offices,agentLocations}:{representatives:Rep[];offices:Office[];agentLocations:AgentLocation[]}) {
 const [reps,setReps]=useState(representatives),[sites,setSites]=useState(offices),[locations,setLocations]=useState(agentLocations),[busy,setBusy]=useState(false),[notice,setNotice]=useState("");
 const supabase=createClient();
 async function saveRep(form:FormData){
  setBusy(true);setNotice("");
  const payload={country_code:String(form.get("country_code")).toUpperCase(),display_name:String(form.get("display_name")),title:String(form.get("title")),organization_name:String(form.get("organization_name")||"")||null,public_city:String(form.get("public_city")||"")||null,public_phone:String(form.get("public_phone")||"")||null,public_email:String(form.get("public_email")||"")||null,verification_status:"verified",status:"active",show_publicly:true};
  const {data,error}=await supabase.from("country_representatives").insert(payload).select("id,country_code,display_name,title,public_city,public_phone,public_email,verification_status,status,show_publicly").single();
  if(error){setNotice("Hitilafu: "+error.message);}else{const {data:{user}}=await supabase.auth.getUser();await supabase.from("global_presence_audit_log").insert({actor_id:user?.id,record_type:"country_representative",record_id:data.id,action:"created_verified_and_published",after_data:payload});setReps(v=>[data,...v]);setNotice("Country Representative ameongezwa na kuthibitishwa.");}
  setBusy(false);
 }
 async function saveOffice(form:FormData){
  setBusy(true);setNotice("");
  const payload={country_code:String(form.get("office_country")).toUpperCase(),office_name:String(form.get("office_name")),office_type:String(form.get("office_type")),city:String(form.get("office_city")||"")||null,public_address:String(form.get("public_address")||"")||null,public_phone:String(form.get("office_phone")||"")||null,verification_status:"verified",status:"active",show_publicly:true};
  const {data,error}=await supabase.from("country_offices").insert(payload).select("id,country_code,office_name,office_type,city,public_address,public_phone,verification_status,status,show_publicly").single();
  if(error){setNotice("Hitilafu: "+error.message);}else{const {data:{user}}=await supabase.auth.getUser();await supabase.from("global_presence_audit_log").insert({actor_id:user?.id,record_type:"country_office",record_id:data.id,action:"created_verified_and_published",after_data:payload});setSites(v=>[data,...v]);setNotice("Country Office imeongezwa na kuthibitishwa.");}
  setBusy(false);
 }
 async function setActive(kind:"country_representatives"|"country_offices",id:string,active:boolean){
  const {error}=await supabase.from(kind).update({status:active?"active":"inactive",show_publicly:active,verification_status:active?"verified":"verified"}).eq("id",id);
  if(error){setNotice(error.message);return;}
  const {data:{user}}=await supabase.auth.getUser();await supabase.from("global_presence_audit_log").insert({actor_id:user?.id,record_type:kind==="country_representatives"?"country_representative":"country_office",record_id:id,action:active?"activated":"deactivated"});
  if(kind==="country_representatives")setReps(v=>v.map(x=>x.id===id?{...x,status:active?"active":"inactive",show_publicly:active}:x));
  else setSites(v=>v.map(x=>x.id===id?{...x,status:active?"active":"inactive",show_publicly:active}:x));
 }
 async function reviewLocation(row:AgentLocation,decision:"approved"|"rejected"){
  const {data:{user}}=await supabase.auth.getUser();const {error}=await supabase.from("agent_location_profiles").update({review_status:decision,reviewed_by:user?.id,reviewed_at:new Date().toISOString()}).eq("id",row.id);
  if(error){setNotice(error.message);return;}
  await supabase.from("global_presence_audit_log").insert({actor_id:user?.id,record_type:"agent_location",record_id:row.id,action:"location_"+decision,after_data:{review_status:decision}});
  setLocations(v=>v.map(x=>x.id===row.id?{...x,review_status:decision}:x));setNotice("Agent location review saved.");
 }
 return <div style={{display:"grid",gap:24}}>
  <section><h3>Agent Location Review ({locations.filter(x=>x.review_status==="pending").length} pending)</h3>{locations.length===0?<p className="form-note">No agent location submissions yet.</p>:locations.map(row=><article className="content-card" key={row.id} style={{marginTop:10}}><strong>{row.country_code} · {[row.city,row.district,row.region].filter(Boolean).join(", ")||"Location details"}</strong><p className="form-note">{[row.ward,row.neighbourhood,row.service_address].filter(Boolean).join(" · ")} · {row.location_type} · Public consent: {row.public_listing_consent?"Yes":"No"} · {row.review_status}</p>{row.review_status==="pending"&&<div style={{display:"flex",gap:8}}><button className="button button-small" onClick={()=>reviewLocation(row,"approved")}>Approve location</button><button className="button button-small button-ghost" onClick={()=>reviewLocation(row,"rejected")}>Reject</button></div>}</article>)}</section>
  {notice&&<p className="form-success" role="status">{notice}</p>}
  <section><h3>Appoint Country Representative</h3><p className="form-note">Kuweka taarifa hapa kunathibitisha na kuchapisha taarifa za umma. Hakikisha uteuzi na taarifa zimethibitishwa kabla ya kuhifadhi.</p>
   <form className="content-card" action={saveRep}><div className="form-grid">
    <div className="field"><label>Country code *</label><input name="country_code" required minLength={2} maxLength={2} placeholder="TZ"/></div>
    <div className="field"><label>Representative full name *</label><input name="display_name" required/></div>
    <div className="field"><label>Official title *</label><input name="title" required placeholder="Country Representative"/></div>
    <div className="field"><label>Organization / agency</label><input name="organization_name"/></div>
    <div className="field"><label>Public city</label><input name="public_city"/></div>
    <div className="field"><label>Official phone</label><input name="public_phone"/></div>
    <div className="field full"><label>Official email</label><input name="public_email" type="email"/></div>
   </div><button className="button form-submit" disabled={busy}>Save representative</button></form>
  </section>
  <section><h3>Register Country Office</h3>
   <form className="content-card" action={saveOffice}><div className="form-grid">
    <div className="field"><label>Country code *</label><input name="office_country" required minLength={2} maxLength={2} placeholder="TZ"/></div>
    <div className="field"><label>Office name *</label><input name="office_name" required/></div>
    <div className="field"><label>Office type</label><select name="office_type"><option value="country_office">Country office</option><option value="head_office">Head office</option><option value="regional_office">Regional office</option><option value="service_office">Service office</option></select></div>
    <div className="field"><label>City</label><input name="office_city"/></div>
    <div className="field full"><label>Official public address</label><input name="public_address"/></div>
    <div className="field"><label>Official phone</label><input name="office_phone"/></div>
   </div><button className="button form-submit" disabled={busy}>Save office</button></form>
  </section>
  <section><h3>Country Representatives ({reps.length})</h3>{reps.length===0?<p className="form-note">No representatives have been registered.</p>:reps.map(x=><article className="content-card" key={x.id} style={{marginTop:10}}><strong>{x.display_name}</strong><p className="form-note">{x.title} · {x.country_code} · {x.public_city??"City not listed"} · {x.verification_status}</p><button className="button button-small button-ghost" onClick={()=>setActive("country_representatives",x.id,x.status!=="active")}>{x.status==="active"?"Hide from footer":"Activate and publish"}</button></article>)}</section>
  <section><h3>Country Offices ({sites.length})</h3>{sites.length===0?<p className="form-note">No official offices have been registered.</p>:sites.map(x=><article className="content-card" key={x.id} style={{marginTop:10}}><strong>{x.office_name}</strong><p className="form-note">{x.office_type.replaceAll("_"," ")} · {x.country_code} · {x.city??"City not listed"} · {x.verification_status}</p><button className="button button-small button-ghost" onClick={()=>setActive("country_offices",x.id,x.status!=="active")}>{x.status==="active"?"Hide from footer":"Activate and publish"}</button></article>)}</section>
  <p className="form-note">Public footer shows only records that are verified, active and explicitly published. Each change is recorded in the global presence audit log.</p>
 </div>;
}
