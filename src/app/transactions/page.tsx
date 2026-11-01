import {redirect} from "next/navigation";
import {createClient} from "@/lib/supabase/server";
import CustomerTransactionWorkspace from "./CustomerTransactionWorkspace";
export const dynamic="force-dynamic";
export default async function TransactionsPage(){
 if(!process.env.NEXT_PUBLIC_SUPABASE_URL||!process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY)redirect("/login?message=setup_required");
 const sb=await createClient();const {data:{user}}=await sb.auth.getUser();if(!user)redirect("/login");
 const [{data:transactions,error},{data:countries}]=await Promise.all([
  sb.from("mfa_transactions").select("id,reference_code,agent_id,partner_id,service_code,country_code,currency,payment_network,amount,status,customer_reference,customer_note,created_at").eq("requester_id",user.id).order("created_at",{ascending:false}).limit(100),
  sb.from("mfa_country_settings").select("country_code,country_name,default_currency,supported_currencies").eq("enabled",true).order("country_name")
 ]);
 const ids=(transactions??[]).map(x=>x.id);
 const {data:history}=ids.length?await sb.from("mfa_transaction_status_history").select("id,transaction_id,previous_status,new_status,actor_role,note,created_at").in("transaction_id",ids).order("created_at",{ascending:true}):{data:[]};
 const {data:escrows}=ids.length?await sb.from("mfa_escrow_workflows").select("id,transaction_id,workflow_status,release_conditions,customer_confirmed_at,dispute_status,funds_held,release_executed").in("transaction_id",ids):{data:[]};
 const {data:disputes}=ids.length?await sb.from("mfa_transaction_disputes").select("id,transaction_id,reason_code,dispute_status,description,created_at").in("transaction_id",ids).order("created_at",{ascending:false}):{data:[]};
 return <section className="content-section"><div className="container"><div className="section-kicker">MFA TRANSACTION TRACKING</div><h1 style={{fontSize:42}}>Track a service request</h1><p className="form-note">MFA V1 stores tracking references only. It does not accept deposits, hold funds, transfer money or confirm a real payment.</p>{error?<p className="form-error">Transaction records could not be loaded. Apply the MFA transaction migrations first.</p>:<CustomerTransactionWorkspace initial={transactions??[]} history={history??[]} disputes={disputes??[]} escrows={escrows??[]} countries={countries??[]}/>}</div></section>;
}
