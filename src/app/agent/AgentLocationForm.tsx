"use client";
import {useState} from "react";
import {createClient} from "@/lib/supabase/client";
type Location={country_code:string;region:string|null;district:string|null;city:string|null;ward:string|null;neighbourhood:string|null;service_address:string|null;location_type:string;service_areas:string[];public_listing_consent:boolean;review_status:string}|null;
export default function AgentLocationForm({agentId,initial}:{agentId:string;initial:Location}){
 const [location,setLocation]=useState<Location>(initial),[busy,setBusy]=useState(false),[message,setMessage]=useState("");
 async function save(form:FormData){
  setBusy(true);setMessage("");const supabase=createClient();
  const payload={agent_id:agentId,country_code:String(form.get("country_code")).toUpperCase(),region:String(form.get("region")||"")||null,district:String(form.get("district")||"")||null,city:String(form.get("city")||"")||null,ward:String(form.get("ward")||"")||null,neighbourhood:String(form.get("neighbourhood")||"")||null,service_address:String(form.get("service_address")||"")||null,location_type:String(form.get("location_type")),service_areas:String(form.get("service_areas")||"").split(",").map(x=>x.trim()).filter(Boolean),public_listing_consent:form.get("public_listing_consent")==="on",review_status:"pending"};
  const {data:{user}}=await supabase.auth.getUser();
  const {data:existing}=await supabase.from("agent_location_profiles").select("id,review_status").eq("agent_id",agentId).maybeSingle();
  const result=existing?await supabase.from("agent_location_profiles").update(payload).eq("agent_id",agentId).select().single():await supabase.from("agent_location_profiles").insert(payload).select().single();
  if(result.error){setMessage("Imeshindikana kuhifadhi: "+result.error.message);}else{setLocation(result.data as Location);setMessage("Taarifa zimehifadhiwa na kutumwa kwa ukaguzi wa MFA.");}
  setBusy(false);
 }
 return <form className="content-card" action={save}><p className="form-note">Jaza eneo la huduma. Anuani ya nyumbani haitachapishwa. Taarifa mpya zinahitaji ukaguzi wa MFA.</p><div className="form-grid">
  <div className="field"><label>Nchi (ISO code) *</label><input name="country_code" required maxLength={2} defaultValue={location?.country_code??"TZ"}/></div>
  <div className="field"><label>Mkoa / Region</label><input name="region" defaultValue={location?.region??""}/></div>
  <div className="field"><label>Wilaya</label><input name="district" defaultValue={location?.district??""}/></div>
  <div className="field"><label>Mji / City</label><input name="city" defaultValue={location?.city??""}/></div>
  <div className="field"><label>Kata / Ward</label><input name="ward" defaultValue={location?.ward??""}/></div>
  <div className="field"><label>Mtaa / Eneo</label><input name="neighbourhood" defaultValue={location?.neighbourhood??""}/></div>
  <div className="field full"><label>Anuani ya biashara / huduma</label><input name="service_address" defaultValue={location?.service_address??""}/></div>
  <div className="field"><label>Aina ya eneo</label><select name="location_type" defaultValue={location?.location_type??"business"}><option value="business">Business location</option><option value="service_point">Service point</option><option value="residential">Residential (private)</option></select></div>
  <div className="field"><label>Maeneo unayohudumia (tenganisha kwa koma)</label><input name="service_areas" defaultValue={(location?.service_areas??[]).join(", ")}/></div>
  <div className="field full"><label className="check-option"><input type="checkbox" name="public_listing_consent" defaultChecked={location?.public_listing_consent??false}/> Nimeruhusu kuonyesha taarifa za eneo la biashara/huduma zilizoidhinishwa hadharani.</label></div>
 </div><p className="form-note">Hali ya ukaguzi: {(location?.review_status??"not submitted").toUpperCase()}</p>{message&&<p className="form-success" role="status">{message}</p>}<button className="button form-submit" disabled={busy}>{busy?"Inahifadhi...":"Hifadhi taarifa za eneo"}</button></form>;
}
