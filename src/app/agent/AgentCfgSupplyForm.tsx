"use client";
import {useState} from "react";
import {useRouter} from "next/navigation";
import {createClient} from "@/lib/supabase/client";

type Supply = {
  claimed_supply_usd:number;
  verified_supply_usd:number|null;
  evidence_reference:string|null;
  verification_status:string;
  verification_reason:string|null;
  last_checked_at:string|null;
}|null;

export default function AgentCfgSupplyForm({initial,agentStatus}:{initial:Supply;agentStatus:string}){
  const router=useRouter();
  const [row,setRow]=useState<Supply>(initial);
  const [busy,setBusy]=useState(false);
  const [notice,setNotice]=useState("");
  async function submit(form:FormData){
    setBusy(true);setNotice("");
    const amount=Number(form.get("claimed_supply_usd"));
    const reference=String(form.get("evidence_reference")||"").trim();
    if(!Number.isFinite(amount)||amount<0||!reference||reference.length>500){
      setNotice("Weka kiasi sahihi na rejea ya uthibitisho wa CFG Supply.");
      setBusy(false);return;
    }
    const {error}=await createClient().rpc("mfa_submit_agent_cfg_supply",{
      p_claimed_supply_usd:amount,
      p_evidence_reference:reference
    });
    if(error){setNotice("Imeshindikana kutuma CFG Supply: "+error.message);}
    else{
      setRow({claimed_supply_usd:amount,verified_supply_usd:null,evidence_reference:reference,verification_status:"pending",verification_reason:null,last_checked_at:null});
      setNotice("CFG Supply imetumwa kwa uhakiki. Akaunti itakuwa ACTIVE baada ya MFA kuthibitisha angalau USD 50 equivalent.");
      router.refresh();
    }
    setBusy(false);
  }
  const status=row?.verification_status??"not_submitted";
  const isActive=agentStatus==="verified"&&status==="verified"&&Number(row?.verified_supply_usd)>=50;
  const operationalStatus=isActive?"ACTIVE":agentStatus==="suspended"||status==="suspended"?"SUSPENDED":agentStatus!=="verified"?"PENDING MFA VERIFICATION":status==="rejected"?"SUPPLY REJECTED":"PENDING CFG SUPPLY VERIFICATION";
  return <div style={{display:"grid",gap:14}}>
    <div className="portal-tile">
      <strong>Minimum CFG Supply · USD 50</strong>
      <span>Agent account status: <b>{operationalStatus}</b></span>
      {row&&<span>Submission: {row.claimed_supply_usd.toLocaleString()} USD equivalent · {status.replaceAll("_"," ").toUpperCase()}</span>}
      {row?.verified_supply_usd!==null&&row?.verified_supply_usd!==undefined&&<span>Verified CFG Supply: {row.verified_supply_usd.toLocaleString()} USD equivalent</span>}
      {row?.verification_reason&&<span>Admin note: {row.verification_reason}</span>}
    </div>
    <form className="content-card" action={submit}>
      <h3>Submit CFG Supply verification</h3>
      <p className="form-note">Weka thamani unayodai kuwa nayo kwa USD equivalent na external reference inayoweza kuhakikiwa. MFA haipokei wala kuhifadhi CFG hapa; uthibitisho unafanywa kwa chanzo kilichoidhinishwa.</p>
      <div className="form-grid">
        <div className="field"><label>Claimed CFG Supply (USD equivalent) *</label><input name="claimed_supply_usd" type="number" min="0" step="0.01" required defaultValue={row?.claimed_supply_usd??50}/></div>
        <div className="field"><label>CFG reference / evidence ID *</label><input name="evidence_reference" required maxLength={500} defaultValue={row?.evidence_reference??""}/></div>
      </div>
      <button className="button button-small" disabled={busy}>{busy?"Submitting…":"Submit for verification"}</button>
    </form>
    {notice&&<p className="form-note" role="status">{notice}</p>}
  </div>;
}
