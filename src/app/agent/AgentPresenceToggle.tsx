"use client";
import {useState} from "react";
import {createClient} from "@/lib/supabase/client";
export default function AgentPresenceToggle({agentId,initialOnline}:{agentId:string;initialOnline:boolean}){
 const [online,setOnline]=useState(initialOnline),[busy,setBusy]=useState(false),[notice,setNotice]=useState("");
 async function toggle(){setBusy(true);setNotice("");const next=!online;const {error}=await createClient().from("agent_profiles").update({is_online:next}).eq("id",agentId);if(error)setNotice(error.message);else{setOnline(next);setNotice(next?"Umeonekana online kwenye directory.":"Hali yako sasa ni offline.");}setBusy(false);}
 return <div className="portal-tile"><strong>Public availability</strong><p className="form-note">Hali hii itaonekana kwenye public directory kwa agent aliyethibitishwa.</p><button type="button" className="button button-small" disabled={busy} onClick={toggle}>{busy?"Saving…":online?"Set offline":"Set online"}</button><p className="form-note" role="status">{notice||("Current status: "+(online?"ONLINE":"OFFLINE"))}</p></div>;
}
