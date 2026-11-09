"use client";
import {useState} from "react";
import {createClient} from "@/lib/supabase/client";
type Tx={id:string;reference_code:string;status:string;amount:number;currency:string;service_code:string;payment_network:string|null;customer_note:string|null;created_at:string;evidence_reference:string|null};
export default function AgentTrackedTransactions({initial}:{initial:Tx[]}){
 const [rows,setRows]=useState(initial),[evidence,setEvidence]=useState<Record<string,string>>({}),[busy,setBusy]=useState(""),[notice,setNotice]=useState("");
 async function advance(row:Tx,next:"PAYMENT_PENDING"|"PAYMENT_SUBMITTED"){
  setBusy(row.id);setNotice("");
  const {data,error}=await createClient().from("mfa_transactions").update({status:next,evidence_reference:evidence[row.id]??row.evidence_reference}).eq("id",row.id).select("id,status,evidence_reference").single();
  if(error)setNotice(error.message);else{setRows(old=>old.map(x=>x.id===row.id?{...x,status:data.status,evidence_reference:data.evidence_reference}:x));setNotice("Transaction tracking status imehifadhiwa. Hakuna malipo yaliyotekelezwa.");}
  setBusy("");
 }
 if(!rows.length)return <p className="form-note">Hakuna MFA tracking transactions ulizopewa bado.</p>;
 return <div>{notice&&<p className="form-note" role="status">{notice}</p>}{rows.map(row=><article className="content-card" key={row.id} style={{marginTop:12}}>
  <strong>{row.reference_code}</strong><p>{row.service_code} · {row.amount.toLocaleString()} {row.currency} · {row.status}</p>
  <p className="form-note">{row.payment_network??"Network not specified"} · {new Date(row.created_at).toLocaleString()}</p>
  {row.customer_note&&<p>{row.customer_note}</p>}
  <div className="field"><label>Evidence reference (no PIN/OTP)</label><input maxLength={500} value={evidence[row.id]??row.evidence_reference??""} onChange={e=>setEvidence(v=>({...v,[row.id]:e.target.value}))}/></div>
  <div style={{display:"flex",gap:8,marginTop:12,flexWrap:"wrap"}}>
   {row.status==="PENDING_AGENT"&&<button className="button button-small" disabled={!!busy} onClick={()=>advance(row,"PAYMENT_PENDING")}>Mark payment pending</button>}
   {row.status==="PAYMENT_PENDING"&&<button className="button button-small" disabled={!!busy} onClick={()=>advance(row,"PAYMENT_SUBMITTED")}>Submit evidence reference</button>}
  </div><p className="form-note" style={{marginTop:10}}>Agent hawezi kuthibitisha malipo au kukamilisha transaction. Hayo yanahitaji mapitio ya admin/partner.</p>
 </article>)}</div>;
}
