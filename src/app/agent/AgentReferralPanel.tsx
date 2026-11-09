"use client";
import {useState} from "react";
type Entry={id:string;currency:string;referral_commission:number;company_revenue:number;company_share_reward_pct:number;referred_agent_id:string;calculated_at:string;eligible_until:string};
export default function AgentReferralPanel({code,entries}:{code:string;entries:Entry[]}){
 const [copied,setCopied]=useState(false);
 const link=typeof window!=="undefined"?window.location.origin+"/become-agent?ref="+encodeURIComponent(code):"/become-agent?ref="+encodeURIComponent(code);
 async function copy(){try{await navigator.clipboard.writeText(link);setCopied(true);window.setTimeout(()=>setCopied(false),1800);}catch{setCopied(false);}}
 const totals=entries.reduce((a,e)=>{a[e.currency]=(a[e.currency]??0)+Number(e.referral_commission);return a;},{} as Record<string,number>);
 return <div>
  <div className="portal-tile"><strong>Your agent referral code</strong><span style={{fontSize:22,fontWeight:800}}>{code}</span></div>
  <div className="field" style={{marginTop:12}}><label htmlFor="mfa-referral-link">Direct invitation link</label><input id="mfa-referral-link" readOnly value={link}/></div>
  <button className="button" type="button" onClick={copy} style={{marginTop:10}}>{copied?"Copied":"Copy invitation link"} <span>↗</span></button>
  <p className="form-note" style={{marginTop:12}}>Referral reward: 10% of MFA company share for up to 12 months from the invited agent becoming operationally active. Only completed and verified eligible transactions count. This is a non-payable calculation record in V1; no withdrawals or payouts are enabled.</p>
  <div className="portal-grid" style={{marginTop:12}}>{Object.entries(totals).map(([currency,total])=><div className="portal-tile" key={currency}><strong>Referral calculations · {currency}</strong><span style={{fontSize:24,fontWeight:800}}>{total.toLocaleString(undefined,{maximumFractionDigits:2})}</span></div>)}</div>
  <h3 style={{marginTop:18}}>Referral calculation history</h3>
  {entries.length===0?<p className="form-note">No eligible referral calculations yet.</p>:entries.map(e=><div className="portal-tile" key={e.id} style={{marginTop:8}}><strong>{e.currency} {Number(e.referral_commission).toLocaleString(undefined,{maximumFractionDigits:2})}</strong><span>From company share · {Number(e.company_share_reward_pct)}% · {new Date(e.calculated_at).toLocaleString()}</span><span>Invited agent ID: {e.referred_agent_id.slice(0,8)}… · Eligibility ends {new Date(e.eligible_until).toLocaleDateString()}</span></div>)}
 </div>;
}
