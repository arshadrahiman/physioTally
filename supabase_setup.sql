-- ==============================================================================
-- PHYSIOTALLY AUTOMATIC DATABASE & TRIGGER SETUP
-- Run this script in your Supabase Dashboard:
-- SQL Editor -> New Query -> Paste & Click RUN (or Cmd+Enter / Ctrl+Enter)
-- ==============================================================================

-- 1. Create PROFILES Table (Includes compressed Base64 Logo & Signature)
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  name TEXT,
  qualification TEXT,
  registration_number TEXT,
  clinic_name TEXT,
  practice_type TEXT DEFAULT 'Freelance / Home Visit Physiotherapist',
  phone TEXT,
  upi_id TEXT,
  work_hours TEXT DEFAULT '9:00 AM - 7:00 PM',
  address TEXT,
  logo_base64 TEXT,
  signature_base64 TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Ensure columns exist if table was already created earlier
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS logo_base64 TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS signature_base64 TEXT;

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public and users can access profiles" ON public.profiles;
CREATE POLICY "Public and users can access profiles"
ON public.profiles FOR ALL USING (true) WITH CHECK (true);


-- 2. Create SUBSCRIPTIONS Table
CREATE TABLE IF NOT EXISTS public.subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  phone TEXT,
  tier TEXT DEFAULT 'free',
  plan_name TEXT DEFAULT 'Free Starter Plan',
  free_quota INT DEFAULT 5,
  invoices_generated INT DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow subscriptions sync" ON public.subscriptions;
CREATE POLICY "Allow subscriptions sync"
ON public.subscriptions FOR ALL USING (true) WITH CHECK (true);


-- 3. Create ACTIVATION_KEYS Table (Separate table for constant / promo keys)
CREATE TABLE IF NOT EXISTS public.activation_keys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT UNIQUE NOT NULL,
  key_type TEXT DEFAULT 'pro', -- 'pro' or 'bonus'
  bonus_bills INT DEFAULT 3,
  plan_name TEXT DEFAULT 'Physio Pro Annual',
  duration_days INT DEFAULT 365,
  is_active BOOLEAN DEFAULT TRUE,
  max_uses INT DEFAULT 1,     -- -1 for unlimited uses
  used_count INT DEFAULT 0,
  expires_at TIMESTAMPTZ,
  last_used_at TIMESTAMPTZ,
  last_used_by TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.activation_keys ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow activation keys check and redeem" ON public.activation_keys;
CREATE POLICY "Allow activation keys check and redeem"
ON public.activation_keys FOR ALL USING (true) WITH CHECK (true);


-- ==============================================================================
-- 4. AUTOMATIC EMAIL CONFIRMATION TRIGGER (Fixes: "Email not confirmed")
-- ==============================================================================
UPDATE auth.users 
SET email_confirmed_at = COALESCE(email_confirmed_at, NOW()) 
WHERE email_confirmed_at IS NULL;

CREATE OR REPLACE FUNCTION public.auto_confirm_new_user()
RETURNS trigger AS $$
BEGIN
  NEW.email_confirmed_at = COALESCE(NEW.email_confirmed_at, NOW());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_auto_confirm ON auth.users;
CREATE TRIGGER on_auth_user_auto_confirm
  BEFORE INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.auto_confirm_new_user();


-- ==============================================================================
-- 5. AUTOMATIC ROW CREATION TRIGGER (Profiles with Images & Subscriptions on Signup)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
  v_phone TEXT;
BEGIN
  v_phone := COALESCE(NEW.raw_user_meta_data->>'phone', '');

  -- 1. Automatically insert/update in public.profiles with Base64 Logo & Signature
  INSERT INTO public.profiles (
    id,
    email,
    name,
    qualification,
    registration_number,
    clinic_name,
    practice_type,
    phone,
    upi_id,
    work_hours,
    address,
    logo_base64,
    signature_base64,
    updated_at
  )
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', ''),
    COALESCE(NEW.raw_user_meta_data->>'qualification', ''),
    COALESCE(NEW.raw_user_meta_data->>'registration_number', ''),
    COALESCE(NEW.raw_user_meta_data->>'clinic_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'practice_type', 'Freelance / Home Visit Physiotherapist'),
    v_phone,
    COALESCE(NEW.raw_user_meta_data->>'upi_id', ''),
    COALESCE(NEW.raw_user_meta_data->>'work_hours', '9:00 AM - 7:00 PM'),
    COALESCE(NEW.raw_user_meta_data->>'address', ''),
    COALESCE(NEW.raw_user_meta_data->>'logo_base64', ''),
    COALESCE(NEW.raw_user_meta_data->>'signature_base64', ''),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    name = CASE WHEN EXCLUDED.name <> '' THEN EXCLUDED.name ELSE public.profiles.name END,
    logo_base64 = CASE WHEN EXCLUDED.logo_base64 <> '' THEN EXCLUDED.logo_base64 ELSE public.profiles.logo_base64 END,
    signature_base64 = CASE WHEN EXCLUDED.signature_base64 <> '' THEN EXCLUDED.signature_base64 ELSE public.profiles.signature_base64 END,
    updated_at = NOW();

  -- 2. Automatically insert into public.subscriptions
  INSERT INTO public.subscriptions (
    user_id,
    email,
    phone,
    tier,
    plan_name,
    free_quota,
    invoices_generated,
    is_active,
    created_at,
    updated_at
  )
  VALUES (
    NEW.id,
    NEW.email,
    v_phone,
    'free',
    'Free Starter Plan',
    5,
    0,
    TRUE,
    NOW(),
    NOW()
  )
  ON CONFLICT DO NOTHING;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger whenever a new user signs up in auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ==============================================================================
-- 6. SEED SAMPLE ACTIVATION KEYS
-- ==============================================================================
INSERT INTO public.activation_keys (code, key_type, bonus_bills, plan_name, duration_days, is_active, max_uses)
VALUES 
  ('PHYSIO-VIP-2026', 'pro', 0, 'Physio Pro Annual (Cloud VIP)', 365, true, 100),
  ('PHYSIO-LIFETIME', 'pro', 0, 'Physio Pro Lifetime Access', 36500, true, 50),
  ('BONUS3BILLS', 'bonus', 3, 'Emergency Patient Top-up (+3 Bills)', 0, true, 500)
ON CONFLICT (code) DO NOTHING;

-- Force PostgREST to reload its schema cache
NOTIFY pgrst, 'reload schema';
