"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";

type ReviewAction = "approve" | "reject" | "request_information" | "suspend";

export async function reviewAgentApplication(input: {
  agentId: string;
  action: ReviewAction;
  reason: string;
  evidenceReference: string;
}) {
  if (!input || typeof input.agentId !== "string" || !/^[0-9a-f-]{36}$/i.test(input.agentId)) {
    return { ok: false, error: "Invalid agent application reference." };
  }
  if (!["approve", "reject", "request_information", "suspend"].includes(input.action)) {
    return { ok: false, error: "Unsupported review action." };
  }
  const reason = String(input.reason ?? "").trim().slice(0, 1000);
  const evidenceReference = String(input.evidenceReference ?? "").trim().slice(0, 1000);
  if (["reject", "request_information", "suspend"].includes(input.action) && !reason) {
    return { ok: false, error: "Enter a reason before taking this action." };
  }

  const supabase = await createClient();
  const { data: { user }, error: authError } = await supabase.auth.getUser();
  if (authError || !user) return { ok: false, error: "Please sign in again." };

  const { data: aal } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
  if (aal?.currentLevel !== "aal2") return { ok: false, error: "Administrator MFA (AAL2) is required." };

  const { data: profile } = await supabase.from("profiles").select("role").eq("id", user.id).maybeSingle();
  if (profile?.role !== "super_admin") return { ok: false, error: "Super Admin permission is required." };

  const { error } = await supabase.rpc("mfa_review_agent_application", {
    p_agent_id: input.agentId,
    p_action: input.action,
    p_reason: reason || null,
    p_evidence_reference: evidenceReference || null,
  });
  if (error) return { ok: false, error: error.message };

  revalidatePath("/admin");
  revalidatePath("/agents");
  return { ok: true, message: "Agent application review saved. Transaction permissions remain disabled." };
}
