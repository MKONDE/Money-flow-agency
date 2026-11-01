"use client";

import { useMemo, useState } from "react";
import { createClient } from "@/lib/supabase/client";

type RequestRow = {
  id: string; reference_code: string; service_type: string; request_mode: string;
  request_status: string; amount: number | null; currency: string | null;
  customer_note: string | null; created_at: string; assigned_agent_id: string | null;
};
type AgentRow = {
  id: string; brand_name: string; city: string | null; region: string | null;
  country_code: string; status: string;
};

export default function AdminWorkspace({ initialRequests, agents }: { initialRequests: RequestRow[]; agents: AgentRow[] }) {
  const [requests, setRequests] = useState(initialRequests);
  const [assignments, setAssignments] = useState<Record<string, string>>({});
  const [busy, setBusy] = useState<string | null>(null);
  const [message, setMessage] = useState("");
  const supabase = useMemo(() => createClient(), []);

  async function assign(request: RequestRow) {
    const agentId = assignments[request.id];
    if (!agentId) { setMessage("Chagua agent kabla ya ku-assign."); return; }
    setBusy(request.id); setMessage("");
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) { setMessage("Session imeisha. Ingia tena."); setBusy(null); return; }

    const { data, error } = await supabase.from("service_requests")
      .update({ assigned_agent_id: agentId })
      .eq("id", request.id).eq("demo_only", true).is("assigned_agent_id", null)
      .select("id").maybeSingle();

    if (error || !data) {
      setMessage(error?.message ?? "Ombi halikuweza kupewa agent. Huenda tayari limepewa mtu mwingine.");
      setBusy(null); return;
    }

    const { error: eventError } = await supabase.from("service_request_events").insert({
      request_id: request.id, actor_id: user.id, actor_type: "admin",
      event_type: "agent_assigned", status: request.request_status,
      note: "Demo request assigned to an approved agent by MFA administrator.",
      metadata: { assigned_agent_id: agentId }
    });

    if (eventError) {
      setMessage("Agent amepewa ombi, lakini tukio la audit halikuweza kuhifadhiwa. Tafadhali kagua audit log.");
    } else {
      setMessage("Ombi limepewa agent kikamilifu (DEMO).");
    }
    setRequests(current => current.map(row => row.id === request.id ? { ...row, assigned_agent_id: agentId } : row));
    setBusy(null);
  }

  return <div>
    <div className="portal-grid" style={{ marginBottom: 22 }}>
      <div className="portal-tile"><strong>Unassigned demo requests</strong><span style={{fontSize:28,fontWeight:800,color:"var(--ink)"}}>{requests.filter(r => !r.assigned_agent_id).length}</span></div>
      <div className="portal-tile"><strong>Verified agents available</strong><span style={{fontSize:28,fontWeight:800,color:"var(--ink)"}}>{agents.length}</span></div>
      <div className="portal-tile"><strong>Operational mode</strong><span>Demo only — hakuna uhamishaji wa fedha.</span></div>
    </div>
    {message && <p className="form-success" role="status" style={{marginBottom:16}}>{message}</p>}
    {requests.length === 0 ? <div className="empty-state"><h2>Hakuna maombi bado</h2><p>Maombi ya wateja yataonekana hapa baada ya kutumwa.</p></div> :
      <div style={{display:"grid",gap:14}}>
        {requests.map(request => {
          const selectedAgent = agents.find(agent => agent.id === (assignments[request.id] ?? ""));
          return <article className="content-card" key={request.id}>
            <div style={{display:"flex",justifyContent:"space-between",gap:12,flexWrap:"wrap",alignItems:"center"}}>
              <div><span className="badge-status">{request.request_status.replaceAll("_"," ").toUpperCase()}</span><h3 style={{fontSize:19,margin:"12px 0 5px"}}>{request.reference_code}</h3><p className="form-note" style={{margin:0}}>{request.service_type.replaceAll("_"," ")} · {request.request_mode.replaceAll("_"," ")}</p></div>
              <div style={{textAlign:"right"}}><strong>{request.amount == null ? "Amount not specified" : `${request.amount.toLocaleString()} ${request.currency ?? ""}`}</strong><p className="form-note">{new Date(request.created_at).toLocaleString()}</p></div>
            </div>
            {request.customer_note && <p style={{fontSize:13,lineHeight:1.7,marginTop:14}}>{request.customer_note}</p>}
            {request.assigned_agent_id ? <p className="form-success" style={{marginTop:14}}>Assigned: {agents.find(a => a.id === request.assigned_agent_id)?.brand_name ?? "Agent assigned"} </p> :
              <div style={{display:"flex",gap:12,alignItems:"end",flexWrap:"wrap",marginTop:18}}>
                <div className="field" style={{flex:"1 1 260px"}}>
                  <label htmlFor={`agent-${request.id}`}>Assign verified agent</label>
                  <select id={`agent-${request.id}`} value={assignments[request.id] ?? ""} onChange={e => setAssignments(v => ({...v,[request.id]:e.target.value}))}>
                    <option value="">Select agent</option>
                    {agents.map(agent => <option key={agent.id} value={agent.id}>{agent.brand_name} — {[agent.city,agent.region,agent.country_code].filter(Boolean).join(", ")}</option>)}
                  </select>
                </div>
                <button className="button button-small" type="button" disabled={busy === request.id || !assignments[request.id] || !selectedAgent} onClick={() => assign(request)}>
                  {busy === request.id ? "Assigning..." : "Assign request"}
                </button>
              </div>}
          </article>;
        })}
      </div>}
    <p className="form-note" style={{marginTop:18}}>Kazi hii inahusu maombi ya DEMO pekee. Agent anasaidia mteja; haombi PIN, OTP, password wala kupokea fedha kwenye akaunti binafsi.</p>
  </div>;
}
