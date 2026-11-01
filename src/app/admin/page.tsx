import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import AdminWorkspace from "./AdminWorkspace";
import GlobalPresenceWorkspace from "./GlobalPresenceWorkspace";

export const dynamic = "force-dynamic";

export default async function AdminPortalPage() {
  if (!process.env.NEXT_PUBLIC_SUPABASE_URL || !process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY) redirect("/login?message=setup_required");
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  const { data: profile } = await supabase.from("profiles").select("role").eq("id", user.id).maybeSingle();
  if (profile?.role !== "super_admin") redirect("/agent");

  const { data: aal } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
  if (aal?.currentLevel !== "aal2") {
    return <section className="content-section"><div className="container form-shell"><div className="empty-state">
      <div className="empty-state-mark">⌑</div><h2>Administrator MFA required</h2>
      <p>Privileged administrator access is restricted until multi-factor authentication is enrolled and the session reaches assurance level AAL2. No admin actions are available from this session.</p>
    </div></div></section>;
  }

  const [{ count: pending }, { count: verified }, { count: suspended }, { data: requests, error: requestsError }, { data: agents, error: agentsError }, { data: representatives }, { data: offices }] = await Promise.all([
    supabase.from("agent_profiles").select("*", { count: "exact", head: true }).eq("status", "pending"),
    supabase.from("agent_profiles").select("*", { count: "exact", head: true }).eq("status", "verified"),
    supabase.from("agent_profiles").select("*", { count: "exact", head: true }).eq("status", "suspended"),
    supabase.from("service_requests").select("id,reference_code,service_type,request_mode,request_status,amount,currency,customer_note,created_at,assigned_agent_id").eq("demo_only", true).order("created_at", { ascending: false }).limit(100),
    supabase.from("agent_profiles").select("id,brand_name,city,region,country_code,status").eq("status", "verified").order("brand_name").limit(200)
  ]);

  return <section className="content-section"><div className="container">
    <div className="section-kicker">MFA ADMINISTRATION</div>
    <h1 style={{ fontSize: 42 }}>Admin Workspace</h1>
    <p className="form-note">Super Admin only · Country and regional manager access remains disabled until scoped access policies are implemented and tested.</p>
    <div className="portal-grid" style={{ marginTop: 28 }}>
      {[[ "Pending applications", pending ?? 0 ], [ "Verified agents", verified ?? 0 ], [ "Suspended agents", suspended ?? 0 ]].map(([label, value]) =>
        <div className="portal-tile" key={String(label)}><strong>{label}</strong><span style={{ fontSize: 30, fontWeight: 800, color: "var(--ink)" }}>{value}</span></div>
      )}
    </div>
    <div className="content-card" style={{ marginTop: 22 }}>
      <h2 style={{ fontSize: 24 }}>Customer service requests</h2>
      <p className="form-note">Review incoming demo requests and assign them to verified agents. Assignment does not execute a payment or bank transfer.</p>
      {requestsError || agentsError ? <p className="form-error">Data could not be loaded. Check Supabase permissions and try again.</p> :
        <AdminWorkspace initialRequests={requests ?? []} agents={agents ?? []} />}
    </div>
    <div className="content-card" style={{ marginTop: 22 }}>
      <h2 style={{ fontSize: 24 }}>Administration controls</h2>
      <p className="form-note">Agent application review, partner approvals, advertising approvals, fee and commission configuration, guarantees, support cases and full audit review remain separate upcoming modules. No real-money actions are enabled.</p>
    </div>
  </div></section>;
}
