"use client";
import {useState} from "react";
import {createClient} from "@/lib/supabase/client";
export default function AgentPresenceToggle({agentId,initialOnline,initialContactConsent}:{agentId:string;initialOnline:boolean;initialContactConsent:boolean}){
 const [online,setOnline]=useState(initialOnline),[consent,setConsent]=useState(initialContactConsent),[busy,setBusy]=useState(false),[notice,setNotice]=useState("");
 async function toggleOnline(){setBusy(true);setNotice("");const next=!online;const {error}=await createClient().from("agent_profiles").update({is_online:next}).eq("id",agentId);if(error)setNotice(error.message);else{setOnline(next);setNotice(next?"Umeonekana online kwenye directory.":"Hali yako sasa ni offline.");}setBusy(false);}
 async function toggleConsent(){setBusy(true);setNotice("");const next=!consent;const {error}=await createClient().from("agent_profiles").update({public_contact_consent:next}).eq("id",agentId);if(error)setNotice(error.message);else{setConsent(next);setNotice(next?"Umekubali kuonyesha simu na email hadharani.":"Taarifa zako za simu na email zimefichwa kwenye directory.");}setBusy(false);}
 return <div className="portal-tile"><strong>Public availability & contact privacy</strong><p className="form-note">Online status na mawasiliano ya umma hudhibitiwa na wewe. Namba/email haitaonekana bila ridhaa yako.</p>
  <div style={{display:"flex",gap:8,flexWrap:"wrap"}}><button type="button" className="button button-small" disabled={busy} onClick={toggleOnline}>{busy?"Saving…":online?"Set offline":"Set online"}</button>
  <button type="button" className="button button-small button-ghost" disabled={busy} onClick={toggleConsent}>{busy?"Saving…":consent?"Hide my contacts":"Publish my contacts"}</button></div>
  <p className="form-note" role="status">{notice||("Presence: "+(online?"ONLINE":"OFFLINE")+" · Contact consent: "+(consent?"ON":"OFF"))}</p>
 </div>;
}
