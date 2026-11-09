"use client";
import {useState} from "react";
import {createClient} from "@/lib/supabase/client";
type Capital={currency:string;declared_capital:number;declared_transaction_float:number;declaration_notes:string|null}|null;
type Guarantee={id:string;guarantee_type:string;issuer_name:string;guarantee_reference:string;amount:number;currency:string;verification_status:string;verification_reason:string|null;valid_until:string|null};
export default function AgentCapitalDeclarationForm({agentId,initialCapital,initialGuarantees}:{agentId:string;initialCapital:Capital;initialGuarantees:Guarantee[]}){
 const [capital,setCapital]=useState<Capital>(initialCapital),[guarantees,setGuarantees]=useState(initialGuarantees);
 const [notice,setNotice]=useState(""),[busy,setBusy]=useState(false);
 async function saveCapital(form:FormData){
  setBusy(true);setNotice("");
  const currency=String(form.get("currency")||"").trim().toUpperCase();
  const declaredCapital=Number(form.get("declared_capital")),declaredFloat=Number(form.get("declared_transaction_float")||0);
  if(!/^[A-Z]{3}$/.test(currency)||!Number.isFinite(declaredCapital)||declaredCapital<0||!Number.isFinite(declaredFloat)||declaredFloat<0){setNotice("Weka currency code na kiasi sahihi.");setBusy(false);return;}
  const sb=createClient();const result=await sb.from("mfa_agent_capital_profiles").upsert({agent_id:agentId,currency,declared_capital:declaredCapital,declared_transaction_float:declaredFloat,declaration_notes:String(form.get("declaration_notes")||"").trim()||null},{onConflict:"agent_id"}).select("currency,declared_capital,declared_transaction_float,declaration_notes").single();
  if(result.error)setNotice("Imeshindikana kuhifadhi: "+result.error.message);else{setCapital(result.data);setNotice("Tamko la mtaji na float limehifadhiwa. Float ni taarifa tu; si fedha zilizowekwa MFA.");}
  setBusy(false);
 }
 async function submitGuarantee(form:FormData){
  setBusy(true);setNotice("");
  const amount=Number(form.get("amount")),currency=String(form.get("currency")||"").trim().toUpperCase();
  if(!Number.isFinite(amount)||amount<=0||!/^[A-Z]{3}$/.test(currency)){setNotice("Kiasi au currency si sahihi.");setBusy(false);return;}
  const sb=createClient();const result=await sb.from("mfa_agent_guarantees").insert({agent_id:agentId,guarantee_type:String(form.get("guarantee_type")),issuer_name:String(form.get("issuer_name")).trim(),guarantee_reference:String(form.get("guarantee_reference")).trim(),amount,currency,valid_from:String(form.get("valid_from")||"")||null,valid_until:String(form.get("valid_until")||"")||null,evidence_reference:String(form.get("evidence_reference")||"").trim()||null}).select("id,guarantee_type,issuer_name,guarantee_reference,amount,currency,verification_status,verification_reason,valid_until").single();
  if(result.error)setNotice("Imeshindikana kutuma guarantee: "+result.error.message);else{setGuarantees(old=>[result.data,...old]);setNotice("Rejea ya guarantee imetumwa kwa ukaguzi. Hakuna fedha zilizokusanywa.");}
  setBusy(false);
 }
 return <div style={{display:"grid",gap:18}}>
  <form className="content-card" action={saveCapital}>
   <h3>Declared capital & transaction float</h3><p className="form-note">Taarifa hizi ni tamko la agent. MFA haipokei wala kuhifadhi mtaji au float. Security guarantee inarekodiwa kando.</p>
   <div className="form-grid">
    <div className="field"><label>Currency code *</label><input name="currency" maxLength={3} required defaultValue={capital?.currency??"TZS"}/></div>
    <div className="field"><label>Declared capital *</label><input name="declared_capital" type="number" min="0" step="0.01" required defaultValue={capital?.declared_capital??""}/></div>
    <div className="field"><label>Declared transaction float</label><input name="declared_transaction_float" type="number" min="0" step="0.01" defaultValue={capital?.declared_transaction_float??0}/></div>
    <div className="field"><label>Notes</label><input name="declaration_notes" maxLength={1000} defaultValue={capital?.declaration_notes??""}/></div>
   </div><button className="button button-small" disabled={busy}>Save declaration</button>
  </form>
  <form className="content-card" action={submitGuarantee}>
   <h3>Security guarantee reference</h3><p className="form-note">Weka taarifa ya dhamana inayoweza kuthibitishwa. Usiweke PIN, password, OTP au namba kamili ya akaunti ya benki. MFA haitakusanya dhamana hii.</p>
   <div className="form-grid">
    <div className="field"><label>Guarantee type *</label><select name="guarantee_type"><option value="bank_guarantee_reference">Bank guarantee reference</option><option value="insurance_bond_reference">Insurance bond reference</option><option value="licensed_provider_reference">Licensed provider reference</option><option value="other_documentary_reference">Other documentary reference</option></select></div>
    <div className="field"><label>Issuer / institution *</label><input name="issuer_name" required maxLength={160}/></div>
    <div className="field"><label>Guarantee reference *</label><input name="guarantee_reference" required maxLength={160}/></div>
    <div className="field"><label>Guarantee amount *</label><input name="amount" type="number" min="0.01" step="0.01" required/></div>
    <div className="field"><label>Currency *</label><input name="currency" maxLength={3} defaultValue={capital?.currency??"TZS"} required/></div>
    <div className="field"><label>Valid from</label><input name="valid_from" type="date"/></div>
    <div className="field"><label>Valid until</label><input name="valid_until" type="date"/></div>
    <div className="field"><label>Evidence reference</label><input name="evidence_reference" maxLength={500}/></div>
   </div><button className="button button-small" disabled={busy}>Submit guarantee for review</button>
  </form>
  {notice&&<p className="form-note" role="status">{notice}</p>}
  <div className="content-card"><h3>Submitted guarantee references</h3>
   {!guarantees.length?<p className="form-note">No guarantee references submitted.</p>:guarantees.map(g=><article key={g.id} style={{padding:"12px 0",borderBottom:"1px solid var(--line)"}}>
    <strong>{g.issuer_name} · {g.amount.toLocaleString()} {g.currency}</strong>
    <p className="form-note">{g.guarantee_type.replaceAll("_"," ")} · Ref: {g.guarantee_reference} · {g.verification_status.toUpperCase()}{g.valid_until?" · Valid until "+g.valid_until:""}</p>
    {g.verification_reason&&<p className="form-note">{g.verification_reason}</p>}
   </article>)}
  </div>
 </div>;
}
