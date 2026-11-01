"use client";

import { useState } from "react";
import { reviewAgentApplication } from "./actions";

type Application = {
  id: string;
  brand_name: string;
  agent_type: string;
  status: string;
  country_code: string;
  region: string | null;
  city: string | null;
  phone: string | null;
  public_email: string | null;
  description: string | null;
  created_at: string;
};

export default function AgentApplicationReview({ applications }: { applications: Application[] }) {
  const [rows, setRows] = useState(applications);
  const [reasons, setReasons] = useState<Record<string, string>>({});
  const [evidence, setEvidence] = useState<Record<string, string>>({});
  const [busy, setBusy] = useState<string | null>(null);
  const [notice, setNotice] = useState("");

  async function review(row: Application, action: "approve" | "reject" | "request_information" | "suspend") {
    setBusy(row.id);
    setNotice("");
    const result = await reviewAgentApplication({
      agentId: row.id,
      action,
      reason: reasons[row.id] ?? "",
      evidenceReference: evidence[row.id] ?? "",
    });
    if (!result.ok) {
      setNotice(result.error ?? "Review action failed.");
    } else {
      setRows(current => current.filter(item => item.id !== row.id));
      setNotice(result.message ?? "Review saved.");
    }
    setBusy(null);
  }

  return <section>
    {notice && <p className="form-note" role="status">{notice}</p>}
    {rows.length === 0 ? <div className="empty-state"><h3>No pending applications</h3><p>New agent applications will appear here after registration.</p></div> :
      <div style={{ display: "grid", gap: 16 }}>
        {rows.map(row => <article className="content-card" key={row.id}>
          <div style={{ display: "flex", justifyContent: "space-between", gap: 12, flexWrap: "wrap" }}>
            <div>
              <span className="badge-status">PENDING REVIEW</span>
              <h3 style={{ margin: "12px 0 5px" }}>{row.brand_name}</h3>
              <p className="form-note">{row.agent_type} · {[row.city, row.region, row.country_code].filter(Boolean).join(", ")}</p>
            </div>
            <p className="form-note">{new Date(row.created_at).toLocaleString()}</p>
          </div>
          {row.description && <p>{row.description}</p>}
          <p className="form-note">{[row.phone, row.public_email].filter(Boolean).join(" · ")}</p>
          <div className="form-grid" style={{ marginTop: 12 }}>
            <div className="field full">
              <label htmlFor={`review-reason-${row.id}`}>Decision reason / additional information request</label>
              <textarea id={`review-reason-${row.id}`} value={reasons[row.id] ?? ""} maxLength={1000}
                onChange={event => setReasons(current => ({ ...current, [row.id]: event.target.value }))} />
            </div>
            <div className="field full">
              <label htmlFor={`review-evidence-${row.id}`}>Evidence reference (internal reference only)</label>
              <input id={`review-evidence-${row.id}`} value={evidence[row.id] ?? ""} maxLength={1000}
                onChange={event => setEvidence(current => ({ ...current, [row.id]: event.target.value }))} />
            </div>
          </div>
          <div style={{ display: "flex", gap: 8, flexWrap: "wrap", marginTop: 14 }}>
            <button className="button button-small" disabled={busy === row.id} onClick={() => review(row, "approve")}>Approve agent</button>
            <button className="button button-small button-ghost" disabled={busy === row.id} onClick={() => review(row, "request_information")}>Request information</button>
            <button className="button button-small button-ghost" disabled={busy === row.id} onClick={() => review(row, "reject")}>Reject</button>
            <button className="button button-small button-ghost" disabled={busy === row.id} onClick={() => review(row, "suspend")}>Suspend</button>
          </div>
          <p className="form-note" style={{ marginTop: 12 }}>Approval changes listing status only. Transaction-enabled remains false and no financial service is activated.</p>
        </article>)}
      </div>}
  </section>;
}
