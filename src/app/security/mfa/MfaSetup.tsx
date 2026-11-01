"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

type TotpFactor = { id: string; status: string; friendly_name?: string };

export default function MfaSetup() {
  const router = useRouter();
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [factor, setFactor] = useState<TotpFactor | null>(null);
  const [qr, setQr] = useState("");
  const [secret, setSecret] = useState("");
  const [code, setCode] = useState("");
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");

  useEffect(() => {
    let active = true;
    async function initialize() {
      const supabase = createClient();
      try {
        const { data: { user }, error: userError } = await supabase.auth.getUser();
        if (userError || !user) {
          router.replace("/login");
          return;
        }
        const { data: profile } = await supabase.from("profiles").select("role").eq("id", user.id).maybeSingle();
        if (profile?.role !== "super_admin") {
          router.replace("/agent");
          return;
        }
        const { data, error: factorsError } = await supabase.auth.mfa.listFactors();
        if (factorsError) throw factorsError;
        const verified = (data.totp ?? []).find((item) => item.status === "verified");
        if (active && verified) {
          setFactor(verified);
          setMessage("Ingiza namba ya tarakimu sita kutoka kwenye programu yako ya Authenticator.");
        } else if (active) {
          const pending = (data.totp ?? []).filter((item) => item.status !== "verified");
          if (pending.length) {
            setMessage("Kuna usajili wa MFA ambao haujakamilika. Uondoe kwanza kisha anza upya.");
            setFactor(pending[0]);
          } else {
            const { data: enrollment, error: enrollError } = await supabase.auth.mfa.enroll({
              factorType: "totp",
              friendlyName: "MFA Admin Authenticator",
            });
            if (enrollError) throw enrollError;
            setFactor({ id: enrollment.id, status: "unverified" });
            setQr(enrollment.totp.qr_code);
            setSecret(enrollment.totp.secret);
            setMessage("Scan QR code kwa Google Authenticator, Microsoft Authenticator au Authy.");
          }
        }
      } catch (err) {
        if (active) setError(err instanceof Error ? err.message : "Imeshindikana kuanzisha MFA.");
      } finally {
        if (active) setLoading(false);
      }
    }
    void initialize();
    return () => { active = false; };
  }, [router]);

  async function verify() {
    if (!factor) return;
    if (!/^\d{6}$/.test(code.trim())) {
      setError("Ingiza namba sahihi ya tarakimu sita.");
      return;
    }
    setBusy(true);
    setError("");
    try {
      const supabase = createClient();
      const { data: challenge, error: challengeError } = await supabase.auth.mfa.challenge({ factorId: factor.id });
      if (challengeError) throw challengeError;
      const { error: verifyError } = await supabase.auth.mfa.verify({
        factorId: factor.id,
        challengeId: challenge.id,
        code: code.trim(),
      });
      if (verifyError) throw verifyError;
      const { data: aal, error: aalError } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
      if (aalError) throw aalError;
      if (aal.currentLevel !== "aal2") throw new Error("Uthibitisho haujakamilika. Jaribu tena.");
      setMessage("MFA imethibitishwa. Unaelekezwa kwenye Admin Workspace.");
      router.replace("/admin");
      router.refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Namba haijathibitishwa.");
    } finally {
      setBusy(false);
    }
  }

  async function removePendingFactor() {
    if (!factor) return;
    setBusy(true);
    setError("");
    try {
      const supabase = createClient();
      const { error: removeError } = await supabase.auth.mfa.unenroll({ factorId: factor.id });
      if (removeError) throw removeError;
      router.refresh();
      window.location.reload();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Imeshindikana kuondoa usajili ambao haujakamilika.");
    } finally {
      setBusy(false);
    }
  }

  if (loading) return <section className="content-section"><div className="container form-shell"><p className="form-note">Inaangalia hali ya usalama...</p></div></section>;

  return (
    <section className="content-section">
      <div className="container form-shell">
        <div className="section-kicker">MFA ACCOUNT SECURITY</div>
        <h1 style={{ fontSize: 36 }}>Thibitisha akaunti ya Admin</h1>
        <p className="form-note">MFA ya TOTP inalinda shughuli za Super Admin. Hii haifungui huduma za kushikilia au kuhamisha fedha.</p>
        {message && <p className="form-note" role="status">{message}</p>}
        {error && <p className="form-error" role="alert">{error}</p>}
        {qr && <div className="content-card" style={{ margin: "20px 0", textAlign: "center" }}>
          <h2>1. Scan QR code</h2>
          <img src={qr} alt="MFA authenticator QR code" style={{ width: 220, height: 220, margin: "16px auto", background: "white", padding: 8 }} />
          <p className="form-note">Ikiwa huwezi kuscan, tumia secret key hii ndani ya programu yako ya Authenticator:</p>
          <code style={{ display: "block", overflowWrap: "anywhere", userSelect: "all" }}>{secret}</code>
          <p className="form-note">Usishiriki QR code au secret key na mtu mwingine.</p>
        </div>}
        {factor?.status === "unverified" && !qr ? <button className="button form-submit" disabled={busy} onClick={removePendingFactor}>Ondoa usajili usiokamilika na anza upya</button> : factor && <>
          <div className="field" style={{ marginTop: 18 }}>
            <label htmlFor="mfa-code">{qr ? "2. Ingiza code kuthibitisha usajili" : "Ingiza code ya Authenticator"}</label>
            <input id="mfa-code" inputMode="numeric" autoComplete="one-time-code" maxLength={6} value={code} onChange={(event) => setCode(event.target.value.replace(/\D/g, "").slice(0, 6))} placeholder="000000" />
          </div>
          <button className="button form-submit" disabled={busy || code.length !== 6} onClick={verify}>{busy ? "Inathibitisha..." : "Thibitisha MFA na fungua Admin"}</button>
        </>}
      </div>
    </section>
  );
}
