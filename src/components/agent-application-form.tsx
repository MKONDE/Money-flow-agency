"use client";
import { useState, type FormEvent } from "react";
import { createClient } from "@/lib/supabase/client";

const serviceOptions = ["Agent assistance","Customer support","Business services","Agricultural services","Marketplace support","Payment guidance"];
const languageOptions = ["Kiswahili","English","Français","Lingala","Kinyarwanda","Other"];
const networkOptions = ["M-Pesa","Airtel Money","Mixx by Yas","HaloPesa","Bank transfer","Other licensed payment network"];

export function AgentApplicationForm() {
  const [busy,setBusy]=useState(false);
  const [message,setMessage]=useState("");
  const [error,setError]=useState("");
  async function submit(event:FormEvent<HTMLFormElement>){
    event.preventDefault();setBusy(true);setError("");setMessage("");
    const form=new FormData(event.currentTarget);
    const selected=(name:string)=>form.getAll(name).map(String);
    try{
      const supabase=createClient();
      const origin=window.location.origin;
      const {error:authError}=await supabase.auth.signUp({
        email:String(form.get("email")),
        password:String(form.get("password")),
        options:{emailRedirectTo:`${origin}/auth/callback?next=/agent`,data:{
          account_type:"agent",agent_type:String(form.get("agent_type")),brand_name:String(form.get("brand_name")),
          full_name:String(form.get("full_name")),description:String(form.get("description")),country_code:String(form.get("country_code")),
          region:String(form.get("region")),city:String(form.get("city")),service_address:String(form.get("service_address")),
          phone:String(form.get("phone")),website:String(form.get("website")),languages:selected("languages"),services:selected("services"),payment_networks:selected("payment_networks")
        }}
      });
      if(authError)throw authError;
      setMessage("Your account and agent application have been submitted. Check your email to confirm your account. Your listing remains pending until MFA reviews and approves it.");
      event.currentTarget.reset();
    }catch(e){setError(e instanceof Error?e.message:"We could not submit your application. Please try again.");}
    finally{setBusy(false);}
  }
  return <form className="content-card" onSubmit={submit}>
    <div className="portal-tile" style={{marginBottom:18}}><strong>Agent activation requirement</strong><span>Submitting this application does not activate an agent account. After MFA reviews your identity and application, you must submit verifiable CFG Supply of at least USD 50 equivalent. Only after both checks are approved will your operational status become ACTIVE.</span></div>
    <div className="form-grid">
      <div className="field"><label htmlFor="full_name">Full name *</label><input id="full_name" name="full_name" required autoComplete="name"/></div>
      <div className="field"><label htmlFor="agent_type">Applicant type *</label><select id="agent_type" name="agent_type"><option value="individual">Individual agent</option><option value="business">Registered business</option></select></div>
      <div className="field"><label htmlFor="brand_name">Brand / business name *</label><input id="brand_name" name="brand_name" required maxLength={100}/></div>
      <div className="field"><label htmlFor="email">Email address *</label><input id="email" name="email" type="email" required autoComplete="email"/></div>
      <div className="field"><label htmlFor="password">Create password *</label><input id="password" name="password" type="password" required minLength={10} autoComplete="new-password"/><span className="form-note">Use at least 10 characters.</span></div>
      <div className="field"><label htmlFor="phone">Phone number *</label><input id="phone" name="phone" required autoComplete="tel"/></div>
      <div className="field"><label htmlFor="country_code">Country code *</label><input id="country_code" name="country_code" defaultValue="TZ" required maxLength={2}/></div>
      <div className="field"><label htmlFor="region">Region / province</label><input id="region" name="region"/></div>
      <div className="field"><label htmlFor="city">City / district</label><input id="city" name="city"/></div>
      <div className="field"><label htmlFor="service_address">Service address</label><input id="service_address" name="service_address"/></div>
      <div className="field"><label htmlFor="website">Website (optional)</label><input id="website" name="website" type="url" placeholder="https://"/></div>
      <div className="field full"><label htmlFor="description">Describe your business or services</label><textarea id="description" name="description" maxLength={1200}/></div>
      <div className="field full"><label>Languages</label><div className="check-grid">{languageOptions.map(v=><label className="check-option" key={v}><input type="checkbox" name="languages" value={v}/>{v}</label>)}</div></div>
      <div className="field full"><label>Services you provide</label><div className="check-grid">{serviceOptions.map(v=><label className="check-option" key={v}><input type="checkbox" name="services" value={v}/>{v}</label>)}</div></div>
      <div className="field full"><label>Payment networks you support (directory information only)</label><div className="check-grid">{networkOptions.map(v=><label className="check-option" key={v}><input type="checkbox" name="payment_networks" value={v}/>{v}</label>)}</div></div>
    </div>
    <p className="form-note" style={{marginTop:18}}>Submitting an application does not make you a verified agent or authorize financial transactions. MFA will review the application and separately verify the minimum USD 50 equivalent CFG Supply before activation. You can add an HTTPS logo URL from your agent portal after signing in. Image-file upload requires a later Storage bucket setup.</p>
    {error&&<p className="form-error" role="alert">{error}</p>}{message&&<p className="form-success" role="status">{message}</p>}
    <button className="button form-submit" type="submit" disabled={busy}>{busy?"Submitting…":"Submit agent application"} <span>↗</span></button>
  </form>;
}
