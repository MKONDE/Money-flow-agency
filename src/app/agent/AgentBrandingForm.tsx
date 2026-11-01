"use client";
import {useState} from "react";
import {createClient} from "@/lib/supabase/client";
export default function AgentBrandingForm({agentId,initialLogo}:{agentId:string;initialLogo:string|null}){
 const [logo,setLogo]=useState(initialLogo??""),[busy,setBusy]=useState(false),[notice,setNotice]=useState("");
 async function save(form:FormData){
  setBusy(true);setNotice("");const value=String(form.get("logo_url")||"").trim();
  if(value){try{const url=new URL(value);if(url.protocol!=="https:")throw new Error("Logo URL lazima itumie HTTPS.");}catch(e){setNotice(e instanceof Error?e.message:"Weka URL sahihi ya HTTPS.");setBusy(false);return;}}
  const {error}=await createClient().from("agent_profiles").update({logo_url:value||null}).eq("id",agentId);
  if(error)setNotice(error.message);else{setLogo(value);setNotice("Logo URL imehifadhiwa na directory itasasishwa. Unaweza kutumia HTTPS image URL; file upload itafunguliwa baada ya Storage bucket kuidhinishwa.");}
  setBusy(false);
 }
 return <form className="content-card" action={save}><h3>Business logo</h3><p className="form-note">Weka HTTPS image URL ya logo ya biashara yako. MFA bado haijafungua file upload bucket.</p>
  <div className="field"><label htmlFor="agent-logo-url">Logo HTTPS URL</label><input id="agent-logo-url" name="logo_url" type="url" pattern="https://.*" placeholder="https://example.com/logo.png" value={logo} onChange={e=>setLogo(e.target.value)} maxLength={500}/></div>
  <button className="button button-small" disabled={busy}>{busy?"Saving…":"Save logo URL"}</button>{notice&&<p className="form-note" role="status">{notice}</p>}
 </form>;
}
