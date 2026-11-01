-- MFA partner administration must also require an AAL2 Super Admin session.
drop policy if exists partners_admin_all on public.business_partners;
create policy partners_admin_all on public.business_partners
for all to authenticated
using ((select private.current_mfa_role())='super_admin' and (select auth.jwt()->>'aal')='aal2')
with check ((select private.current_mfa_role())='super_admin' and (select auth.jwt()->>'aal')='aal2');
