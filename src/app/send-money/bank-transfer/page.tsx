"use client";

import { FormEvent, useState } from "react";
import Link from "next/link";

const banks = ["CRDB Bank", "NMB Bank", "NBC", "Exim Bank", "Absa Bank", "Stanbic Bank", "Other"];

export default function BankTransferDemoPage() {
  const [reference, setReference] = useState("");
  const [source, setSource] = useState("CRDB Bank");
  const [destination, setDestination] = useState("NMB Bank");
  const [amount, setAmount] = useState("");
  const [country, setCountry] = useState("Tanzania");
  const [mode, setMode] = useState("self");
  const [notice, setNotice] = useState("");

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (source === destination) {
      setNotice("Chagua benki tofauti kwa akaunti ya chanzo na mpokeaji.");
      return;
    }
    if (!Number.isFinite(Number(amount)) || Number(amount) <= 0) {
      setNotice("Weka kiasi halali cha mfano.");
      return;
    }
    setReference("MFA-DEMO-" + Math.random().toString(36).slice(2, 8).toUpperCase());
    setNotice("Ombi la majaribio limetengenezwa. Hakuna fedha zilizotumwa.");
  }

  return (
    <main className="content-section">
      <div className="container" style={{ maxWidth: 820 }}>
        <div className="section-kicker">MFA SEND MONEY · DEMO</div>
        <h1 style={{ fontSize: 40 }}>Bank-to-Bank Transfer</h1>
        <p className="form-note">Mfano: mteja ana fedha CRDB na anataka kutuma kwenda NMB. Benki au mtoa huduma aliyeidhinishwa ndiye hutekeleza muamala halisi.</p>
        <div role="alert" style={{ padding: 16, border: "1px solid #d99a35", borderRadius: 12, background: "#fff8e9", color: "#704b12", margin: "22px 0" }}>
          <strong>DEMO — NOT A REAL BANK TRANSFER</strong><br />
          Usitumie taarifa halisi za akaunti, PIN, OTP, nenosiri au CVV. Hakuna muamala wa fedha unaofanyika hapa.
        </div>
        <form onSubmit={submit} className="content-card" style={{ display: "grid", gap: 16 }}>
          <label>Country
            <select value={country} onChange={e => setCountry(e.target.value)} style={fieldStyle}>
              <option>Tanzania</option><option>Kenya</option><option>Rwanda</option><option>Burundi</option><option>Uganda</option>
            </select>
          </label>
          <label>Source bank — benki yenye fedha
            <select value={source} onChange={e => setSource(e.target.value)} style={fieldStyle}>
              {banks.map(bank => <option key={bank}>{bank}</option>)}
            </select>
          </label>
          <label>Destination bank — benki ya mpokeaji
            <select value={destination} onChange={e => setDestination(e.target.value)} style={fieldStyle}>
              {banks.map(bank => <option key={bank}>{bank}</option>)}
            </select>
          </label>
          <label>Amount (demo only)
            <input inputMode="decimal" value={amount} onChange={e => setAmount(e.target.value)} placeholder="Mfano 100000" style={fieldStyle} />
          </label>
          <fieldset style={{ border: "1px solid #d9e1df", borderRadius: 10, padding: 14 }}>
            <legend>How would you like to proceed?</legend>
            <label style={{ display: "block", marginBottom: 10 }}><input type="radio" checked={mode === "self"} onChange={() => setMode("self")} /> Self-Service — mteja anaendelea mwenyewe kupitia njia rasmi ya benki/mtoa huduma.</label>
            <label style={{ display: "block" }}><input type="radio" checked={mode === "agent"} onChange={() => setMode("agent")} /> Agent-Assisted — wakala anamsaidia mteja kufuata utaratibu rasmi.</label>
          </fieldset>
          <p className="form-note">Kwa demo hii hatuombi namba ya akaunti ya mpokeaji. Mfumo halisi utahitaji taarifa chache zinazohitajika tu, zikiwa zimefichwa (masked) inapowezekana.</p>
          <button className="button" type="submit">Create demo request ↗</button>
          {notice && <p role="status" className="form-note">{notice}</p>}
        </form>
        {reference && <section className="content-card" style={{ marginTop: 20 }}>
          <div className="section-kicker">DEMO REQUEST RECEIPT</div>
          <h2 style={{ fontSize: 24 }}>{reference}</h2>
          <p>{source} → {destination} · {country} · {amount}</p>
          <p>Mode: {mode === "self" ? "Self-Service" : "Agent-Assisted"}</p>
          <ol style={{ lineHeight: 2 }}>
            <li>Request created — DEMO</li>
            <li>Waiting for approved partner route — simulated</li>
            <li>Bank authorization — not performed</li>
            <li>Settlement — not performed</li>
          </ol>
          <strong>DEMO ONLY — This is not proof of payment or a bank receipt.</strong>
        </section>}
        <p style={{ marginTop: 24 }}><Link className="text-link" href="/services">← Back to services</Link></p>
      </div>
    </main>
  );
}

const fieldStyle = {
  display: "block",
  width: "100%",
  marginTop: 7,
  padding: "12px 14px",
  border: "1px solid #cbd5d1",
  borderRadius: 8,
  background: "#fff",
  color: "#182522",
  font: "inherit",
};
