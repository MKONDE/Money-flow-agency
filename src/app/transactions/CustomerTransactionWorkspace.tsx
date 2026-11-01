"use client";
import {useState} from "react";
import {createClient} from "@/lib/supabase/client";
type Tx={id:string;reference_code:string;agent_id:string|null;partner_id:string|null;service_code:string;country_code:string;currency:string;payment_network:string|null;amount:number;status:string;customer_reference:string|null;customer_note:string|null;created_at:string};
type Event={id:number;transaction_id:string;previous_status:string|null;new_status:string;actor_role:string|null;note:string|null;created_at:string};
type Dispute={id:string;transaction_id:string;reason_code:string;dispute_status:string;description:string;created_at:string};
type Country={country_code:string;country_name:string;default_currency:string;supported_currencies:string[]};
const statusLabels=["CREATED","PENDING_AGENT","PAYMENT_PENDING","PAYMENT_SUBMITTED","UNDER_REVIEW","CONFIRMED","COMPLETED","REJECTED","DISPUTED","CANCELLED","EXPIRED"];
export default function CustomerTransactionWorkspace({initial,history,disputes,countries}:{initial:Tx[];history:Event[];disputes:Dispute[];countries:Country[]}){
 const [rows,setRows]=useState(initial),[events,setEvents]=useState(history),[disputeRows,setDisputeRows]=useState(disputes);
 const [busy,setBusy]=useState(false),[notice,setNotice]=useState("");
 async function create(form:FormData){
  setBusy(true);setNotice("");
  const amount=Number(form.get("amount")),country=String(form.get("country_code")||"").toUpperCase(),currency=String(form.get("currency")||"").toUpperCase();
  if(!Number.isFinite(amount)||amount<=0||!/^[A-Z]{2}$/.test(country)||!/^[A-Z]{3}$/.test(currency)){setNotice("Kagua kiasi, nchi na currency.");setBusy(false);return;}
  const sb=createClient();const {data:{user}}=await sb.auth.getUser();if(!user){setNotice("Ingia tena ili kutuma ombi.");setBusy(false);return;}
  const {data,error}=await sb.from("mfa_transactions").insert({requester_id:user.id,service_code:String(form.get("service_code")||"general").trim().toLowerCase(),country_code:country,currency,amount,payment_network:String(form.get("payment_network")||"").trim()||null,customer_reference:String(form.get("customer_reference")||"").trim()||null,customer_note:String(form.get("customer_note")||"").trim()||null,simulation_only:true}).select("id,reference_code,agent_id,partner_id,service_code,country_code,currency,payment_network,amount,status,customer_reference,customer_note,created_at").single();
  if(error){setNotice(error.message);setBusy(false);return;}
  const {data:event}=await sb.from("mfa_transaction_status_history").select("id,transaction_id,previous_status,new_status,actor_role,note,created_at").eq("transaction_id",data.id).single();
  setRows(old=>[data,...old]);if(event)setEvents(old=>[...old,event]);setNotice("Tracking request imeundwa. Hakuna malipo yaliyopokelewa au kutumwa.");(document.getElementById("mfa-tracking-form") as HTMLFormElement|null)?.reset();setBusy(false);
 }
 async function openDispute(row:Tx,form:FormData){
  const {data:{user}}=await createClient().auth.getUser();if(!user){setNotice("Ingia tena.");return;}
  const reason=String(form.get("reason_code")||"other"),description=String(form.get("description")||"").trim();
  if(description.length<10){setNotice("Eleza tatizo kwa angalau herufi 10.");return;}
  const {data,error}=await createClient().from("mfa_transaction_disputes").insert({transaction_id:row.id,opened_by:user.id,reason_code:reason,description}).select("id,transaction_id,reason_code,dispute_status,description,created_at").single();
  if(error)setNotice(error.message);else{setDisputeRows(old=>[data,...old]);setRows(old=>old.map(x=>x.id===row.id?{...x,status:"DISPUTED"}:x));setNotice("Dispute imefunguliwa na transaction imewekwa DISPUTED kwa ukaguzi.");}
 }
 return <div style={{display:"grid",gap:22}}>
  <form id="mfa-tracking-form" className="content-card" action={create}>
   <h2 style={{fontSize:23}}>Create tracking record</h2><p className="form-note">Hii si amri ya kutuma pesa. Ni kumbukumbu ya huduma na rejea ya ufuatiliaji pekee.</p>
   <div className="form-grid">
    <div className="field"><label>Service code *</label><input name="service_code" required maxLength={60} defaultValue="general"/></div>
    <div className="field"><label>Country code *</label><input name="country_code" required maxLength={2} defaultValue={countries[0]?.country_code??"TZ"}/></div>
    <div className="field"><label>Currency *</label><input name="currency" required maxLength={3} defaultValue={countries[0]?.default_currency??"TZS"}/></div>
    <div className="field"><label>Amount to track *</label><input name="amount" type="number" min="0.01" step="0.01" required/></div>
    <div className="field"><label>Payment network reference</label><input name="payment_network" maxLength={100} placeholder="M-Pesa / Bank / Other"/></div>
    <div className="field"><label>Your reference</label><input name="customer_reference" maxLength={120}/></div>
    <div className="field full"><label>Service note</label><textarea name="customer_note" maxLength={1000}/></div>
   </div><button className="button form-submit" disabled={busy}>{busy?"Submitting…":"Create tracking record"}</button>
  </form>
  {notice&&<p className="form-note" role="status">{notice}</p>}
  <section><h2 style={{fontSize:25}}>Your transaction tracking history</h2>{!rows.length?<div className="empty-state"><h3>No tracking records</h3><p>Records you create will appear here.</p></div>:rows.map(row=><article className="content-card" key={row.id} style={{marginTop:14}}>
   <div style={{display:"flex",justifyContent:"space-between",gap:10,flexWrap:"wrap"}}><strong>{row.reference_code}</strong><span className="badge-status">{row.status}</span></div>
   <p>{row.service_code} · {row.amount.toLocaleString()} {row.currency} · {row.country_code}</p><p className="form-note">{row.payment_network??"Network not specified"} · {new Date(row.created_at).toLocaleString()}</p>
   {row.customer_note&&<p>{row.customer_note}</p>}
   <div style={{padding:"12px 0",borderTop:"1px solid var(--line)"}}><strong>Status history</strong>{events.filter(e=>e.transaction_id===row.id).map(e=><p className="form-note" key={e.id}>{e.previous_status?e.previous_status+" → ":""}{e.new_status} · {new Date(e.created_at).toLocaleString()}</p>)}</div>
   {disputeRows.filter(d=>d.transaction_id===row.id).map(d=><p className="form-note" key={d.id}>Dispute: {d.dispute_status.toUpperCase()} · {d.reason_code} · {d.description}</p>)}
   {["PAYMENT_SUBMITTED","UNDER_REVIEW","CONFIRMED","COMPLETED"].includes(row.status)&&!disputeRows.some(d=>d.transaction_id===row.id)&&<details style={{marginTop:12}}><summary>Open a dispute</summary><form action={openDispute.bind(null,row)} className="form-grid" style={{marginTop:12}}><div className="field"><label>Reason</label><select name="reason_code"><option value="service_not_received">Service not received</option><option value="incorrect_details">Incorrect details</option><option value="suspected_fraud">Suspected fraud</option><option value="other">Other</option></select></div><div className="field"><label>Description *</label><textarea name="description" required minLength={10}/></div><button className="button button-small">Submit dispute</button></form></details>}
  </article>)}</section>
  <p className="form-note">Allowed tracking states: {statusLabels.join(" · ")}. Payment evidence is a reference only; never submit PIN, OTP, password or full bank-card details.</p>
 </div>;
}
