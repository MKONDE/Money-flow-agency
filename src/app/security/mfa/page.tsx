import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import MfaSetup from "./MfaSetup";

export const dynamic = "force-dynamic";

export default async function MfaSecurityPage() {
  if (!process.env.NEXT_PUBLIC_SUPABASE_URL || !process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY) redirect("/login");
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login");
  const { data: profile } = await supabase.from("profiles").select("role").eq("id", user.id).maybeSingle();
  if (profile?.role !== "super_admin") redirect("/agent");
  return <MfaSetup />;
}
