"use client";
import {useState,type FormEvent} from "react";
import {createClient} from "@/lib/supabase/client";
type Settings={company_share_reward_pct:number;duration_months:number;enabled:boolean;effective_from:string};
export default function ReferralCommissionSettings({initial}:{initial:Settings|null}){
 const [pct,setPct]=useState(String(initial?.company_share_reward_pct??10));
 const [months,setMonths]=useState(String(initial?.duration_months??12));
 const [enabled,setEnabled]=useState(initial?.enabled??true);
 const [busy,setBusy]=useState(false);const [message,setMessage]=useState("");const [error,setError]=useState("");
 async function save(e:FormEvent<HTMLFormElement>){e.preventDefault();setBusy(true);setMessage("");setError("");try{const {error}=await createClient().rpc("mfa_update_referral_commission_settings",{p_company_share_reward_pct:Number(pct),p_duration_months:Number(months),p_enabled:enabled});if(error)throw error;setMessage("Referral rule updated. New calculations use this rule; existing snapshots remain unchanged.");}catch(err){setError(err instanceof Error?err.message:"Could not update the referral rule.");}finally{setBusy(false);}}
 return <form className="content-card" onSubmit={save} style={{marginTop:22}}>
  <h2 style={{fontSize:24}}>Direct-agent referral commission</h2>
  <p className="form-note">AAL2 Super Admin only. Percentage is calculated from MFA company revenue, not the customer transaction amount, the servicing agent share or operations/risk reserve.</p>
  <div className="form-grid">
   <div className="field"><label htmlFor="referral-pct">Reward as % of MFA company share</label><input id="referral-pct" type="number" min="0" max="100" step="0.01" value={pct} onChange={e=>setPct(e.target.value)} required/></div>
   <div className="field"><label htmlFor="referral-months">Eligibility duration (months)</label><input id="referral-months" type="number" min="1" max="36" step="1" value={months} onChange={e=>setMonths(e.target.value)} required/></div>
   <div className="field full"><label className="check-option"><input type="checkbox" checked={enabled} onChange={e=>setEnabled(e.target.checked)}/> Enable referral calculations for new eligible transactions</label></div>
  </div>
  <p className="form-note">Approved V1 default: 10% of company share for 12 months. Changes apply prospectively; each calculation stores its own rule snapshot.</p>
  {error&&<p className="form-error" role="alert">{error}</p>}{message&&<p className="form-success" role="status">{message}</p>}
  <button className="button" disabled={busy}>{busy?"Saving…":"Save referral rule"} <span>↗</span></button>
 </form>;
}
