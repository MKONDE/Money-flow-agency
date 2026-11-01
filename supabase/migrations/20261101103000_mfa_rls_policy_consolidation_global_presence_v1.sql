-- Consolidate public-read and AAL2 Super Admin SELECT permissions
-- without changing who may read, insert, update, or delete.
do $$
declare t text;
begin
  foreach t in array array['country_offices','country_representatives'] loop
    execute format('drop policy if exists "Super admins manage %s" on public.%I',
      case when t='country_offices' then 'offices' else 'representatives' end, t);

    execute format('drop policy if exists "Public can view approved %s" on public.%I',
      case when t='country_offices' then 'offices' else 'representatives' end, t);

    execute format(
      'create policy %I on public.%I for select to anon, authenticated using (
        (verification_status = ''verified'' and status = ''active'' and show_publicly = true)
        or (
          (select auth.jwt())->>''aal'' = ''aal2''
          and exists (select 1 from public.profiles p
            where p.id = (select auth.uid()) and p.role = ''super_admin'')
        )
      )',
      case when t='country_offices' then 'offices_public_or_admin_read' else 'representatives_public_or_admin_read' end, t);

    execute format(
      'create policy %I on public.%I for insert to authenticated with check (
        (select auth.jwt())->>''aal'' = ''aal2''
        and exists (select 1 from public.profiles p
          where p.id = (select auth.uid()) and p.role = ''super_admin'')
      )',
      case when t='country_offices' then 'offices_admin_insert' else 'representatives_admin_insert' end, t);

    execute format(
      'create policy %I on public.%I for update to authenticated using (
        (select auth.jwt())->>''aal'' = ''aal2''
        and exists (select 1 from public.profiles p
          where p.id = (select auth.uid()) and p.role = ''super_admin'')
      ) with check (
        (select auth.jwt())->>''aal'' = ''aal2''
        and exists (select 1 from public.profiles p
          where p.id = (select auth.uid()) and p.role = ''super_admin'')
      )',
      case when t='country_offices' then 'offices_admin_update' else 'representatives_admin_update' end, t);

    execute format(
      'create policy %I on public.%I for delete to authenticated using (
        (select auth.jwt())->>''aal'' = ''aal2''
        and exists (select 1 from public.profiles p
          where p.id = (select auth.uid()) and p.role = ''super_admin'')
      )',
      case when t='country_offices' then 'offices_admin_delete' else 'representatives_admin_delete' end, t);
  end loop;
end $$;

-- These tables are private request artifacts. Anonymous users have no
-- supported workflow for confirmations or receipts; participant access
-- remains authenticated and row-scoped by existing RLS policies.
revoke all privileges on table public.partner_confirmations from anon;
revoke all privileges on table public.receipt_records from anon;
revoke all privileges on table public.service_request_events from anon;
