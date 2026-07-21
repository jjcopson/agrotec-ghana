-- ============================================================
-- AGROTECH GHANA — CORE SCHEMA
-- Migration 001: Users, Roles, Wallets, Notifications
-- ============================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_cron";
CREATE EXTENSION IF NOT EXISTS "pg_net";

-- ============================================================
-- ENUMS
-- ============================================================

CREATE TYPE user_role AS ENUM (
  'farmer',
  'processing_industry',
  'truck_driver',
  'wholesaler',
  'retailer',
  'enthusiast',
  'expert',
  'customer',
  'admin'
);

CREATE TYPE expert_label AS ENUM (
  'expert',
  'lecturer',
  'consultant'
);

CREATE TYPE verification_status AS ENUM (
  'pending',
  'under_review',
  'approved',
  'rejected'
);

CREATE TYPE transaction_type AS ENUM (
  'credit',
  'debit'
);

CREATE TYPE transaction_status AS ENUM (
  'pending',
  'completed',
  'failed',
  'reversed'
);

CREATE TYPE transaction_reference AS ENUM (
  'wallet_topup',
  'marketplace_payment',
  'marketplace_escrow_release',
  'marketplace_refund',
  'consultation_payment',
  'consultation_refund',
  'transport_payment',
  'transport_refund',
  'course_payment',
  'withdrawal',
  'platform_fee'
);

CREATE TYPE notification_type AS ENUM (
  'order_update',
  'consultation_request',
  'consultation_message',
  'transport_bid',
  'transport_update',
  'payment',
  'verification',
  'knowledge_post',
  'system',
  'review'
);

-- ============================================================
-- USERS (extends Supabase auth.users)
-- ============================================================

CREATE TABLE public.users (
  id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name     TEXT NOT NULL,
  username      TEXT UNIQUE,
  email         TEXT UNIQUE NOT NULL,
  phone         TEXT UNIQUE,
  avatar_url    TEXT,
  bio           TEXT,
  roles         user_role[] NOT NULL DEFAULT '{customer}',
  active_role   user_role NOT NULL DEFAULT 'customer',
  region        TEXT,                        -- Ghana region
  district      TEXT,
  location_lat  DOUBLE PRECISION,
  location_lng  DOUBLE PRECISION,
  is_verified   BOOLEAN NOT NULL DEFAULT FALSE,
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  last_seen_at  TIMESTAMPTZ,
  fcm_token     TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- ROLE-SPECIFIC PROFILE TABLES
-- ============================================================

-- Farmer profiles
CREATE TABLE public.farmer_profiles (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID UNIQUE NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  farm_name       TEXT,
  farm_size_acres DECIMAL(10,2),
  farm_location   TEXT,
  crops_grown     TEXT[],
  livestock       TEXT[],
  farming_type    TEXT,               -- organic, conventional, mixed
  years_farming   INTEGER,
  verification_status verification_status NOT NULL DEFAULT 'pending',
  verified_at     TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Business profiles (processing industry, wholesaler, retailer)
CREATE TABLE public.business_profiles (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id             UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  business_name       TEXT NOT NULL,
  business_type       user_role NOT NULL,       -- processing_industry | wholesaler | retailer
  registration_number TEXT,
  tin_number          TEXT,
  business_address    TEXT,
  business_phone      TEXT,
  business_email      TEXT,
  description         TEXT,
  logo_url            TEXT,
  products_services   TEXT[],
  verification_status verification_status NOT NULL DEFAULT 'pending',
  verified_at         TIMESTAMPTZ,
  rejection_reason    TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Driver profiles
CREATE TABLE public.driver_profiles (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id             UUID UNIQUE NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  license_number      TEXT,
  license_class       TEXT,
  vehicle_type        TEXT,
  vehicle_make        TEXT,
  vehicle_model       TEXT,
  vehicle_year        INTEGER,
  vehicle_plate       TEXT,
  vehicle_capacity_kg DECIMAL(10,2),
  vehicle_photos      TEXT[],
  service_regions     TEXT[],
  is_available        BOOLEAN NOT NULL DEFAULT TRUE,
  rating              DECIMAL(3,2) DEFAULT 0,
  total_trips         INTEGER DEFAULT 0,
  verification_status verification_status NOT NULL DEFAULT 'pending',
  verified_at         TIMESTAMPTZ,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Expert profiles (experts, lecturers, consultants)
CREATE TABLE public.expert_profiles (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id             UUID UNIQUE NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  label               expert_label NOT NULL DEFAULT 'expert',
  specializations     TEXT[] NOT NULL,
  qualifications      TEXT[],
  institution         TEXT,
  years_experience    INTEGER,
  session_price_ghs   DECIMAL(10,2) NOT NULL DEFAULT 0,
  available_days      TEXT[],
  available_hours     JSONB,            -- { start: "08:00", end: "17:00" }
  credentials_urls    TEXT[],           -- uploaded documents
  portfolio_url       TEXT,
  linkedin_url        TEXT,
  rating              DECIMAL(3,2) DEFAULT 0,
  total_consultations INTEGER DEFAULT 0,
  is_available        BOOLEAN NOT NULL DEFAULT FALSE,
  verification_status verification_status NOT NULL DEFAULT 'pending',
  verified_at         TIMESTAMPTZ,
  rejection_reason    TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enthusiast profiles
CREATE TABLE public.enthusiast_profiles (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID UNIQUE NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  interests       TEXT[],
  learning_goals  TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- VERIFICATION DOCUMENTS
-- ============================================================

CREATE TABLE public.verifications (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  role            user_role NOT NULL,
  document_type   TEXT NOT NULL,         -- 'national_id', 'business_reg', 'license', 'credentials'
  document_url    TEXT NOT NULL,
  status          verification_status NOT NULL DEFAULT 'pending',
  reviewed_by     UUID REFERENCES public.users(id),
  review_notes    TEXT,
  submitted_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reviewed_at     TIMESTAMPTZ
);

-- ============================================================
-- WALLETS
-- ============================================================

CREATE TABLE public.wallets (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID UNIQUE NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  balance_ghs     DECIMAL(15,2) NOT NULL DEFAULT 0.00,
  escrow_balance  DECIMAL(15,2) NOT NULL DEFAULT 0.00,   -- locked funds
  total_earned    DECIMAL(15,2) NOT NULL DEFAULT 0.00,
  total_spent     DECIMAL(15,2) NOT NULL DEFAULT 0.00,
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT positive_balance CHECK (balance_ghs >= 0),
  CONSTRAINT positive_escrow CHECK (escrow_balance >= 0)
);

CREATE TABLE public.wallet_transactions (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  wallet_id       UUID NOT NULL REFERENCES public.wallets(id),
  user_id         UUID NOT NULL REFERENCES public.users(id),
  type            transaction_type NOT NULL,
  amount_ghs      DECIMAL(15,2) NOT NULL,
  fee_ghs         DECIMAL(15,2) NOT NULL DEFAULT 0,
  reference_type  transaction_reference NOT NULL,
  reference_id    UUID,                 -- FK to order/consultation/transport etc.
  description     TEXT,
  paystack_ref    TEXT,
  status          transaction_status NOT NULL DEFAULT 'pending',
  metadata        JSONB,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- NOTIFICATIONS
-- ============================================================

CREATE TABLE public.notifications (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  type            notification_type NOT NULL,
  title           TEXT NOT NULL,
  body            TEXT NOT NULL,
  data            JSONB,
  is_read         BOOLEAN NOT NULL DEFAULT FALSE,
  reference_id    UUID,
  reference_type  TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- REVIEWS
-- ============================================================

CREATE TABLE public.reviews (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reviewer_id     UUID NOT NULL REFERENCES public.users(id),
  reviewee_id     UUID NOT NULL REFERENCES public.users(id),
  reference_type  TEXT NOT NULL,   -- 'consultation', 'transport', 'marketplace'
  reference_id    UUID NOT NULL,
  rating          INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment         TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(reviewer_id, reference_type, reference_id)
);

-- ============================================================
-- TRIGGERS: updated_at
-- ============================================================

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER users_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER farmer_profiles_updated_at BEFORE UPDATE ON public.farmer_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER business_profiles_updated_at BEFORE UPDATE ON public.business_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER driver_profiles_updated_at BEFORE UPDATE ON public.driver_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER expert_profiles_updated_at BEFORE UPDATE ON public.expert_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER wallets_updated_at BEFORE UPDATE ON public.wallets FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER wallet_transactions_updated_at BEFORE UPDATE ON public.wallet_transactions FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- TRIGGER: Auto-create wallet on new user
-- ============================================================

CREATE OR REPLACE FUNCTION create_wallet_for_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.wallets (user_id) VALUES (NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_user_created
  AFTER INSERT ON public.users
  FOR EACH ROW EXECUTE FUNCTION create_wallet_for_new_user();

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.farmer_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.business_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expert_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.enthusiast_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.verifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallet_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

-- Users: public read of basic info, own full access
CREATE POLICY "Users can view all profiles" ON public.users FOR SELECT USING (TRUE);
CREATE POLICY "Users can update own profile" ON public.users FOR UPDATE USING (auth.uid() = id);

-- Wallets: private to owner
CREATE POLICY "Users can view own wallet" ON public.wallets FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can view own transactions" ON public.wallet_transactions FOR SELECT USING (auth.uid() = user_id);

-- Notifications: private to owner
CREATE POLICY "Users see own notifications" ON public.notifications FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users update own notifications" ON public.notifications FOR UPDATE USING (auth.uid() = user_id);

-- Role profiles: owner access
CREATE POLICY "Farmers own profile" ON public.farmer_profiles FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Business own profile" ON public.business_profiles FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Drivers own profile" ON public.driver_profiles FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Experts own profile" ON public.expert_profiles FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Enthusiasts own profile" ON public.enthusiast_profiles FOR ALL USING (auth.uid() = user_id);

-- Expert profiles: public read for verified experts
CREATE POLICY "Public can view verified experts" ON public.expert_profiles FOR SELECT USING (verification_status = 'approved');

-- Reviews: public read
CREATE POLICY "Public can view reviews" ON public.reviews FOR SELECT USING (TRUE);
CREATE POLICY "Authenticated users can create reviews" ON public.reviews FOR INSERT WITH CHECK (auth.uid() = reviewer_id);

-- Indexes
CREATE INDEX idx_users_roles ON public.users USING GIN (roles);
CREATE INDEX idx_users_region ON public.users (region);
CREATE INDEX idx_notifications_user ON public.notifications (user_id, is_read, created_at DESC);
CREATE INDEX idx_wallet_transactions_user ON public.wallet_transactions (user_id, created_at DESC);
CREATE INDEX idx_wallet_transactions_ref ON public.wallet_transactions (reference_id);
CREATE INDEX idx_expert_profiles_status ON public.expert_profiles (verification_status);
CREATE INDEX idx_reviews_reviewee ON public.reviews (reviewee_id);
