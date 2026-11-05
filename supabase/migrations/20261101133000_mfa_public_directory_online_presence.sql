-- Privacy-safe public presence, supported payment networks and explicit contact consent.
-- Additive migration for the dedicated Money Flow Agency database.

ALTER TABLE public.agent_profiles
  ADD COLUMN IF NOT EXISTS public_contact_consent boolean NOT NULL DEFAULT false;

ALTER TABLE public.public_agent_directory
  ADD COLUMN IF NOT EXISTS is_online boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS payment_networks text[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS public_phone text,
  ADD COLUMN IF NOT EXISTS public_email text;

-- Agents may explicitly control whether their contact details appear publicly.
GRANT UPDATE (public_contact_consent) ON public.agent_profiles TO authenticated;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_constraint
    WHERE conname = 'mfa_agent_logo_https_url_check'
      AND conrelid = 'public.agent_profiles'::regclass
  ) THEN
    ALTER TABLE public.agent_profiles
      ADD CONSTRAINT mfa_agent_logo_https_url_check
      CHECK (logo_url IS NULL OR logo_url ~ '^https://[^[:space:]]+$');
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_public_agent_directory()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    DELETE FROM public.public_agent_directory WHERE id = OLD.id;
    RETURN OLD;
  END IF;

  IF NEW.status = 'verified' THEN
    INSERT INTO public.public_agent_directory (
      id, brand_name, description, country_code, region, city,
      services, languages, logo_url, is_online, payment_networks,
      public_phone, public_email, synced_at
    )
    VALUES (
      NEW.id, NEW.brand_name, NEW.description, NEW.country_code, NEW.region, NEW.city,
      NEW.services, NEW.languages, NEW.logo_url, NEW.is_online, NEW.payment_networks,
      CASE WHEN NEW.public_contact_consent THEN NEW.phone ELSE NULL END,
      CASE WHEN NEW.public_contact_consent THEN NEW.public_email ELSE NULL END,
      now()
    )
    ON CONFLICT (id) DO UPDATE SET
      brand_name = EXCLUDED.brand_name,
      description = EXCLUDED.description,
      country_code = EXCLUDED.country_code,
      region = EXCLUDED.region,
      city = EXCLUDED.city,
      services = EXCLUDED.services,
      languages = EXCLUDED.languages,
      logo_url = EXCLUDED.logo_url,
      is_online = EXCLUDED.is_online,
      payment_networks = EXCLUDED.payment_networks,
      public_phone = EXCLUDED.public_phone,
      public_email = EXCLUDED.public_email,
      synced_at = now();
  ELSE
    DELETE FROM public.public_agent_directory WHERE id = NEW.id;
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.sync_public_agent_directory() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS sync_public_agent_directory_trigger ON public.agent_profiles;
CREATE TRIGGER sync_public_agent_directory_trigger
AFTER INSERT OR UPDATE OF
  brand_name, description, country_code, region, city, services, languages,
  logo_url, is_online, payment_networks, public_contact_consent, phone, public_email, status
ON public.agent_profiles
FOR EACH ROW
EXECUTE FUNCTION public.sync_public_agent_directory();

DROP TRIGGER IF EXISTS sync_public_agent_directory_delete_trigger ON public.agent_profiles;
CREATE TRIGGER sync_public_agent_directory_delete_trigger
AFTER DELETE ON public.agent_profiles
FOR EACH ROW
EXECUTE FUNCTION public.sync_public_agent_directory();

-- Backfill verified agents while preserving explicit contact-consent defaults.
INSERT INTO public.public_agent_directory (
  id, brand_name, description, country_code, region, city,
  services, languages, logo_url, is_online, payment_networks,
  public_phone, public_email, synced_at
)
SELECT
  id, brand_name, description, country_code, region, city,
  services, languages, logo_url, is_online, payment_networks,
  CASE WHEN public_contact_consent THEN phone ELSE NULL END,
  CASE WHEN public_contact_consent THEN public_email ELSE NULL END,
  now()
FROM public.agent_profiles
WHERE status = 'verified'
ON CONFLICT (id) DO UPDATE SET
  brand_name = EXCLUDED.brand_name,
  description = EXCLUDED.description,
  country_code = EXCLUDED.country_code,
  region = EXCLUDED.region,
  city = EXCLUDED.city,
  services = EXCLUDED.services,
  languages = EXCLUDED.languages,
  logo_url = EXCLUDED.logo_url,
  is_online = EXCLUDED.is_online,
  payment_networks = EXCLUDED.payment_networks,
  public_phone = EXCLUDED.public_phone,
  public_email = EXCLUDED.public_email,
  synced_at = now();
