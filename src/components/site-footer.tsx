import Image from "next/image";
import Link from "next/link";
import { createClient } from "@/lib/supabase/server";

export async function SiteFooter() {
  let representatives: {id:string;country_code:string;display_name:string;title:string;public_city:string|null;public_phone:string|null;public_email:string|null}[] = [];
  let offices: {id:string;country_code:string;office_name:string;city:string|null;public_address:string|null;public_phone:string|null}[] = [];
  if (process.env.NEXT_PUBLIC_SUPABASE_URL && process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY) {
    try {
      const supabase = await createClient();
      const [{data: reps}, {data: sites}] = await Promise.all([
        supabase.from("country_representatives").select("id,country_code,display_name,title,public_city,public_phone,public_email").eq("verification_status","verified").eq("status","active").eq("show_publicly",true).order("country_code"),
        supabase.from("country_offices").select("id,country_code,office_name,city,public_address,public_phone").eq("verification_status","verified").eq("status","active").eq("show_publicly",true).order("country_code")
      ]);
      representatives = reps ?? [];
      offices = sites ?? [];
    } catch {
      // The public footer remains available if the directory is temporarily unavailable.
    }
  }
  return (
    <footer className="site-footer">
      <div className="container footer-grid">
        <div>
          <Link href="/" className="brand footer-brand" aria-label="Money Flow Agency home">
            <Image src="/mfa-logo.svg" alt="Money Flow Agency" width={104} height={104} />
          </Link>
          <p className="footer-note">An independent agent network and business services platform built for trusted connections.</p>
        </div>
        <div><strong>Explore</strong><Link href="/agents">Find an agent</Link><Link href="/services">Our services</Link><Link href="/partners">Business partners</Link></div>
        <div><strong>Support</strong><Link href="/help">Help & complaints</Link><Link href="/contact">Contact</Link><Link href="/advertising">Advertising</Link></div>
        <div><strong>Legal</strong><Link href="/privacy">Privacy</Link><Link href="/terms">Terms & compliance</Link></div>
      </div>
      {(representatives.length>0 || offices.length>0) && <div className="container" style={{paddingTop:28}}>
        <strong style={{fontSize:13}}>MFA Global Representation</strong>
        <div style={{display:"grid",gridTemplateColumns:"repeat(auto-fit,minmax(220px,1fr))",gap:14,marginTop:14}}>
          {representatives.map(rep=><div key={rep.id} style={{border:"1px solid rgba(255,255,255,.15)",borderRadius:8,padding:14}}>
            <strong style={{fontSize:12}}>{rep.country_code} · {rep.display_name}</strong><p style={{fontSize:11,color:"#c8b9d8",margin:"6px 0"}}>{rep.title}{rep.public_city ? " · " + rep.public_city : ""}</p>
            {rep.public_phone&&<p style={{fontSize:11,color:"#c8b9d8",margin:"4px 0"}}>{rep.public_phone}</p>}
            {rep.public_email&&<a style={{fontSize:11,color:"#e9b45e"}} href={"mailto:"+rep.public_email}>{rep.public_email}</a>}
          </div>)}
          {offices.map(office=><div key={office.id} style={{border:"1px solid rgba(255,255,255,.15)",borderRadius:8,padding:14}}>
            <strong style={{fontSize:12}}>{office.country_code} · {office.office_name}</strong><p style={{fontSize:11,color:"#c8b9d8",margin:"6px 0"}}>{office.city??"Official office"}</p>
            {office.public_address&&<p style={{fontSize:11,color:"#c8b9d8",margin:"4px 0"}}>{office.public_address}</p>}
            {office.public_phone&&<p style={{fontSize:11,color:"#c8b9d8",margin:"4px 0"}}>{office.public_phone}</p>}
          </div>)}
        </div>
      </div>}
      <div className="container footer-bottom"><span>© {new Date().getFullYear()} Money Flow Agency.</span><span>Independent platform · Partner data stays separate</span></div>
    </footer>
  );
}
