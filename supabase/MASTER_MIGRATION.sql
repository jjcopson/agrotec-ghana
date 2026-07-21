-- ================================================================
-- AGROTECH GHANA — MASTER MIGRATION (safe to re-run)
-- Paste this ENTIRE file into Supabase SQL Editor and click Run
-- ================================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_cron";
CREATE EXTENSION IF NOT EXISTS "pg_net";

-- ================================================================
-- ENUMS (drop first so re-run is safe)
-- ================================================================
DO $$ BEGIN
  CREATE TYPE user_role AS ENUM (
    'farmer','processing_industry','truck_driver','wholesaler',
    'retailer','enthusiast','expert','customer','admin'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE expert_label AS ENUM ('expert','lecturer','consultant');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE verification_status AS ENUM ('pending','under_review','approved','rejected');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE transaction_type AS ENUM ('credit','debit');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE transaction_status AS ENUM ('pending','completed','failed','reversed');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE transaction_reference AS ENUM (
    'wallet_topup','marketplace_payment','marketplace_escrow_release',
    'marketplace_refund','consultation_payment','consultation_refund',
    'transport_payment','transport_refund','course_payment','withdrawal','platform_fee'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE notification_type AS ENUM (
    'order_update','consultation_request','consultation_message',
    'transport_bid','transport_update','payment','verification',
    'knowledge_post','system','review'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE listing_status AS ENUM ('draft','active','sold_out','suspended','deleted');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE listing_category AS ENUM (
    'crops','livestock','equipment','inputs','processed_goods',
    'seeds','fertilizers','pesticides','irrigation','other'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE order_status AS ENUM (
    'pending_payment','paid','processing','shipped','delivered',
    'completed','disputed','refunded','cancelled'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE escrow_status AS ENUM ('held','released','refunded','disputed');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE consultation_status AS ENUM (
    'requested','accepted','in_progress','free_threshold_reached',
    'paid','completed','cancelled','expired'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE transport_job_status AS ENUM (
    'open','bidding','assigned','in_transit','delivered','completed','cancelled','disputed'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE bid_status AS ENUM ('pending','accepted','rejected','withdrawn');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE content_status AS ENUM ('draft','published','archived','flagged');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE content_type AS ENUM ('article','video','infographic','podcast');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ================================================================
-- CORE TABLES
-- ================================================================
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  username TEXT UNIQUE,
  email TEXT UNIQUE NOT NULL,
  phone TEXT UNIQUE,
  avatar_url TEXT,
  bio TEXT,
  roles user_role[] NOT NULL DEFAULT '{customer}',
  active_role user_role NOT NULL DEFAULT 'customer',
  region TEXT, district TEXT,
  location_lat DOUBLE PRECISION, location_lng DOUBLE PRECISION,
  is_verified BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  last_seen_at TIMESTAMPTZ, fcm_token TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.farmer_profiles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID UNIQUE NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  farm_name TEXT, farm_size_acres DECIMAL(10,2), farm_location TEXT,
  crops_grown TEXT[], livestock TEXT[], farming_type TEXT, years_farming INTEGER,
  verification_status verification_status NOT NULL DEFAULT 'pending',
  verified_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.business_profiles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  business_name TEXT NOT NULL, business_type user_role NOT NULL,
  registration_number TEXT, tin_number TEXT, business_address TEXT,
  business_phone TEXT, business_email TEXT, description TEXT, logo_url TEXT,
  products_services TEXT[],
  verification_status verification_status NOT NULL DEFAULT 'pending',
  verified_at TIMESTAMPTZ, rejection_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.driver_profiles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID UNIQUE NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  license_number TEXT, license_class TEXT, vehicle_type TEXT,
  vehicle_make TEXT, vehicle_model TEXT, vehicle_year INTEGER,
  vehicle_plate TEXT, vehicle_capacity_kg DECIMAL(10,2),
  vehicle_photos TEXT[], service_regions TEXT[],
  is_available BOOLEAN NOT NULL DEFAULT TRUE,
  rating DECIMAL(3,2) DEFAULT 0, total_trips INTEGER DEFAULT 0,
  verification_status verification_status NOT NULL DEFAULT 'pending',
  verified_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.expert_profiles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID UNIQUE NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  label expert_label NOT NULL DEFAULT 'expert',
  specializations TEXT[] NOT NULL,
  qualifications TEXT[], institution TEXT, years_experience INTEGER,
  session_price_ghs DECIMAL(10,2) NOT NULL DEFAULT 0,
  available_days TEXT[], available_hours JSONB,
  credentials_urls TEXT[], portfolio_url TEXT, linkedin_url TEXT,
  rating DECIMAL(3,2) DEFAULT 0, total_consultations INTEGER DEFAULT 0,
  is_available BOOLEAN NOT NULL DEFAULT FALSE,
  verification_status verification_status NOT NULL DEFAULT 'pending',
  verified_at TIMESTAMPTZ, rejection_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.enthusiast_profiles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID UNIQUE NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  interests TEXT[], learning_goals TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.verifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  role user_role NOT NULL, document_type TEXT NOT NULL, document_url TEXT NOT NULL,
  status verification_status NOT NULL DEFAULT 'pending',
  reviewed_by UUID REFERENCES public.users(id),
  review_notes TEXT,
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reviewed_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.wallets (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID UNIQUE NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  balance_ghs DECIMAL(15,2) NOT NULL DEFAULT 0.00,
  escrow_balance DECIMAL(15,2) NOT NULL DEFAULT 0.00,
  total_earned DECIMAL(15,2) NOT NULL DEFAULT 0.00,
  total_spent DECIMAL(15,2) NOT NULL DEFAULT 0.00,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT positive_balance CHECK (balance_ghs >= 0),
  CONSTRAINT positive_escrow CHECK (escrow_balance >= 0)
);

CREATE TABLE IF NOT EXISTS public.wallet_transactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  wallet_id UUID NOT NULL REFERENCES public.wallets(id),
  user_id UUID NOT NULL REFERENCES public.users(id),
  type transaction_type NOT NULL,
  amount_ghs DECIMAL(15,2) NOT NULL,
  fee_ghs DECIMAL(15,2) NOT NULL DEFAULT 0,
  reference_type transaction_reference NOT NULL,
  reference_id UUID, description TEXT, paystack_ref TEXT,
  status transaction_status NOT NULL DEFAULT 'pending',
  metadata JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  type notification_type NOT NULL,
  title TEXT NOT NULL, body TEXT NOT NULL,
  data JSONB, is_read BOOLEAN NOT NULL DEFAULT FALSE,
  reference_id UUID, reference_type TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.reviews (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reviewer_id UUID NOT NULL REFERENCES public.users(id),
  reviewee_id UUID NOT NULL REFERENCES public.users(id),
  reference_type TEXT NOT NULL, reference_id UUID NOT NULL,
  rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(reviewer_id, reference_type, reference_id)
);

-- ================================================================
-- MARKETPLACE TABLES
-- ================================================================
CREATE TABLE IF NOT EXISTS public.marketplace_listings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  seller_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL, description TEXT,
  category listing_category NOT NULL, subcategory TEXT,
  price_ghs DECIMAL(15,2) NOT NULL,
  unit TEXT NOT NULL DEFAULT 'kg',
  quantity DECIMAL(15,2) NOT NULL, quantity_available DECIMAL(15,2) NOT NULL,
  images TEXT[] NOT NULL DEFAULT '{}',
  location TEXT, region TEXT, district TEXT,
  lat DOUBLE PRECISION, lng DOUBLE PRECISION, tags TEXT[],
  status listing_status NOT NULL DEFAULT 'active',
  views_count INTEGER NOT NULL DEFAULT 0,
  is_negotiable BOOLEAN NOT NULL DEFAULT FALSE,
  delivery_available BOOLEAN NOT NULL DEFAULT FALSE,
  pickup_available BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  buyer_id UUID NOT NULL REFERENCES public.users(id),
  seller_id UUID NOT NULL REFERENCES public.users(id),
  status order_status NOT NULL DEFAULT 'pending_payment',
  subtotal_ghs DECIMAL(15,2) NOT NULL,
  delivery_fee_ghs DECIMAL(15,2) NOT NULL DEFAULT 0,
  platform_fee_ghs DECIMAL(15,2) NOT NULL DEFAULT 0,
  total_ghs DECIMAL(15,2) NOT NULL,
  delivery_address TEXT, delivery_region TEXT,
  delivery_lat DOUBLE PRECISION, delivery_lng DOUBLE PRECISION,
  notes TEXT, paystack_ref TEXT, payment_method TEXT,
  dispute_reason TEXT, disputed_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ, completed_at TIMESTAMPTZ, cancelled_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.order_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  listing_id UUID NOT NULL REFERENCES public.marketplace_listings(id),
  quantity DECIMAL(15,2) NOT NULL,
  unit_price_ghs DECIMAL(15,2) NOT NULL,
  total_price_ghs DECIMAL(15,2) NOT NULL,
  snapshot JSONB
);

CREATE TABLE IF NOT EXISTS public.escrow_records (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID UNIQUE NOT NULL REFERENCES public.orders(id),
  buyer_id UUID NOT NULL REFERENCES public.users(id),
  seller_id UUID NOT NULL REFERENCES public.users(id),
  amount_ghs DECIMAL(15,2) NOT NULL,
  platform_fee_ghs DECIMAL(15,2) NOT NULL DEFAULT 0,
  status escrow_status NOT NULL DEFAULT 'held',
  held_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  auto_release_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '3 days'),
  released_at TIMESTAMPTZ, release_triggered_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.saved_listings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  listing_id UUID NOT NULL REFERENCES public.marketplace_listings(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, listing_id)
);

CREATE TABLE IF NOT EXISTS public.market_prices (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  commodity TEXT NOT NULL, unit TEXT NOT NULL DEFAULT 'kg',
  price_ghs DECIMAL(10,2) NOT NULL, market_name TEXT, region TEXT,
  source TEXT, submitted_by UUID REFERENCES public.users(id),
  is_verified BOOLEAN NOT NULL DEFAULT FALSE,
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ================================================================
-- CONSULTATION & TRANSPORT TABLES
-- ================================================================
CREATE TABLE IF NOT EXISTS public.consultations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  client_id UUID NOT NULL REFERENCES public.users(id),
  expert_id UUID NOT NULL REFERENCES public.users(id),
  expert_profile_id UUID NOT NULL REFERENCES public.expert_profiles(id),
  status consultation_status NOT NULL DEFAULT 'requested',
  topic TEXT NOT NULL, description TEXT,
  session_price_ghs DECIMAL(10,2) NOT NULL DEFAULT 0,
  platform_fee_ghs DECIMAL(10,2) NOT NULL DEFAULT 0,
  expert_earnings_ghs DECIMAL(10,2) NOT NULL DEFAULT 0,
  message_count INTEGER NOT NULL DEFAULT 0,
  is_free_threshold_hit BOOLEAN NOT NULL DEFAULT FALSE,
  free_ended_at TIMESTAMPTZ, free_start_at TIMESTAMPTZ,
  paid_start_at TIMESTAMPTZ, ended_at TIMESTAMPTZ, duration_minutes INTEGER,
  payment_status TEXT NOT NULL DEFAULT 'unpaid',
  paystack_ref TEXT, payment_method TEXT,
  scheduled_at TIMESTAMPTZ, accepted_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ, cancel_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.consultation_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  consultation_id UUID NOT NULL REFERENCES public.consultations(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES public.users(id),
  content TEXT NOT NULL,
  message_type TEXT NOT NULL DEFAULT 'text',
  media_url TEXT,
  is_free BOOLEAN NOT NULL DEFAULT TRUE,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.transport_jobs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  poster_id UUID NOT NULL REFERENCES public.users(id),
  assigned_driver_id UUID REFERENCES public.users(id),
  status transport_job_status NOT NULL DEFAULT 'open',
  title TEXT NOT NULL, description TEXT, cargo_type TEXT NOT NULL,
  cargo_weight_kg DECIMAL(10,2), cargo_volume_m3 DECIMAL(10,2), cargo_images TEXT[],
  pickup_address TEXT NOT NULL, pickup_region TEXT NOT NULL,
  pickup_lat DOUBLE PRECISION, pickup_lng DOUBLE PRECISION, pickup_date DATE NOT NULL,
  delivery_address TEXT NOT NULL, delivery_region TEXT NOT NULL,
  delivery_lat DOUBLE PRECISION, delivery_lng DOUBLE PRECISION,
  budget_ghs DECIMAL(10,2), agreed_price_ghs DECIMAL(10,2),
  platform_fee_ghs DECIMAL(10,2) DEFAULT 0,
  assigned_at TIMESTAMPTZ, pickup_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ, completed_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ, cancel_reason TEXT,
  dispute_reason TEXT, disputed_at TIMESTAMPTZ,
  payment_status TEXT NOT NULL DEFAULT 'unpaid',
  paystack_ref TEXT, payment_method TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.transport_bids (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  job_id UUID NOT NULL REFERENCES public.transport_jobs(id) ON DELETE CASCADE,
  driver_id UUID NOT NULL REFERENCES public.users(id),
  bid_amount_ghs DECIMAL(10,2) NOT NULL,
  message TEXT, estimated_days INTEGER,
  status bid_status NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(job_id, driver_id)
);

-- ================================================================
-- KNOWLEDGE TABLES
-- ================================================================
CREATE TABLE IF NOT EXISTS public.knowledge_posts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  author_id UUID NOT NULL REFERENCES public.users(id),
  title TEXT NOT NULL, slug TEXT UNIQUE NOT NULL,
  summary TEXT, content TEXT NOT NULL,
  content_type content_type NOT NULL DEFAULT 'article',
  cover_image_url TEXT, media_url TEXT, tags TEXT[], category TEXT,
  status content_status NOT NULL DEFAULT 'draft',
  is_premium BOOLEAN NOT NULL DEFAULT FALSE,
  views_count INTEGER NOT NULL DEFAULT 0,
  likes_count INTEGER NOT NULL DEFAULT 0,
  comments_count INTEGER NOT NULL DEFAULT 0,
  published_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.knowledge_post_likes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_id UUID NOT NULL REFERENCES public.knowledge_posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(post_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.knowledge_post_comments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_id UUID NOT NULL REFERENCES public.knowledge_posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.users(id),
  parent_id UUID REFERENCES public.knowledge_post_comments(id),
  content TEXT NOT NULL, likes_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.courses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  instructor_id UUID NOT NULL REFERENCES public.users(id),
  title TEXT NOT NULL, slug TEXT UNIQUE NOT NULL,
  description TEXT, cover_image_url TEXT, preview_video TEXT,
  category TEXT, tags TEXT[],
  difficulty TEXT NOT NULL DEFAULT 'beginner',
  language TEXT NOT NULL DEFAULT 'en',
  is_free BOOLEAN NOT NULL DEFAULT FALSE,
  price_ghs DECIMAL(10,2) NOT NULL DEFAULT 0,
  status content_status NOT NULL DEFAULT 'draft',
  enrolled_count INTEGER NOT NULL DEFAULT 0,
  rating DECIMAL(3,2) DEFAULT 0,
  total_lessons INTEGER NOT NULL DEFAULT 0,
  duration_hours DECIMAL(5,2), published_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.course_sections (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  title TEXT NOT NULL, order_index INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.course_lessons (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  section_id UUID REFERENCES public.course_sections(id),
  title TEXT NOT NULL, content TEXT, video_url TEXT,
  duration_mins INTEGER, order_index INTEGER NOT NULL DEFAULT 0,
  is_preview BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.course_enrollments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  course_id UUID NOT NULL REFERENCES public.courses(id),
  user_id UUID NOT NULL REFERENCES public.users(id),
  payment_status TEXT NOT NULL DEFAULT 'unpaid',
  amount_paid_ghs DECIMAL(10,2) NOT NULL DEFAULT 0,
  paystack_ref TEXT, progress_pct INTEGER NOT NULL DEFAULT 0,
  completed_at TIMESTAMPTZ,
  enrolled_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(course_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.lesson_progress (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  enrollment_id UUID NOT NULL REFERENCES public.course_enrollments(id) ON DELETE CASCADE,
  lesson_id UUID NOT NULL REFERENCES public.course_lessons(id),
  is_completed BOOLEAN NOT NULL DEFAULT FALSE,
  watch_seconds INTEGER NOT NULL DEFAULT 0, completed_at TIMESTAMPTZ,
  UNIQUE(enrollment_id, lesson_id)
);

CREATE TABLE IF NOT EXISTS public.forum_posts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  author_id UUID NOT NULL REFERENCES public.users(id),
  title TEXT NOT NULL, content TEXT NOT NULL, tags TEXT[], category TEXT,
  is_expert_only BOOLEAN NOT NULL DEFAULT FALSE,
  views_count INTEGER NOT NULL DEFAULT 0,
  answers_count INTEGER NOT NULL DEFAULT 0,
  is_solved BOOLEAN NOT NULL DEFAULT FALSE,
  accepted_answer_id UUID,
  status content_status NOT NULL DEFAULT 'published',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.forum_answers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_id UUID NOT NULL REFERENCES public.forum_posts(id) ON DELETE CASCADE,
  author_id UUID NOT NULL REFERENCES public.users(id),
  content TEXT NOT NULL,
  is_expert BOOLEAN NOT NULL DEFAULT FALSE,
  upvotes INTEGER NOT NULL DEFAULT 0,
  is_accepted BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ================================================================
-- TRIGGERS (safe re-run — drop first)
-- ================================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$ BEGIN NEW.updated_at = NOW(); RETURN NEW; END; $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS users_updated_at ON public.users;
CREATE TRIGGER users_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS farmer_profiles_updated_at ON public.farmer_profiles;
CREATE TRIGGER farmer_profiles_updated_at BEFORE UPDATE ON public.farmer_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS business_profiles_updated_at ON public.business_profiles;
CREATE TRIGGER business_profiles_updated_at BEFORE UPDATE ON public.business_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS driver_profiles_updated_at ON public.driver_profiles;
CREATE TRIGGER driver_profiles_updated_at BEFORE UPDATE ON public.driver_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS expert_profiles_updated_at ON public.expert_profiles;
CREATE TRIGGER expert_profiles_updated_at BEFORE UPDATE ON public.expert_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS wallets_updated_at ON public.wallets;
CREATE TRIGGER wallets_updated_at BEFORE UPDATE ON public.wallets FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS wallet_transactions_updated_at ON public.wallet_transactions;
CREATE TRIGGER wallet_transactions_updated_at BEFORE UPDATE ON public.wallet_transactions FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS marketplace_listings_updated_at ON public.marketplace_listings;
CREATE TRIGGER marketplace_listings_updated_at BEFORE UPDATE ON public.marketplace_listings FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS orders_updated_at ON public.orders;
CREATE TRIGGER orders_updated_at BEFORE UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS escrow_records_updated_at ON public.escrow_records;
CREATE TRIGGER escrow_records_updated_at BEFORE UPDATE ON public.escrow_records FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS consultations_updated_at ON public.consultations;
CREATE TRIGGER consultations_updated_at BEFORE UPDATE ON public.consultations FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS transport_jobs_updated_at ON public.transport_jobs;
CREATE TRIGGER transport_jobs_updated_at BEFORE UPDATE ON public.transport_jobs FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS transport_bids_updated_at ON public.transport_bids;
CREATE TRIGGER transport_bids_updated_at BEFORE UPDATE ON public.transport_bids FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS knowledge_posts_updated_at ON public.knowledge_posts;
CREATE TRIGGER knowledge_posts_updated_at BEFORE UPDATE ON public.knowledge_posts FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS courses_updated_at ON public.courses;
CREATE TRIGGER courses_updated_at BEFORE UPDATE ON public.courses FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS forum_posts_updated_at ON public.forum_posts;
CREATE TRIGGER forum_posts_updated_at BEFORE UPDATE ON public.forum_posts FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Auto-create wallet on signup
CREATE OR REPLACE FUNCTION create_wallet_for_new_user()
RETURNS TRIGGER AS $$ BEGIN INSERT INTO public.wallets (user_id) VALUES (NEW.id); RETURN NEW; END; $$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_user_created ON public.users;
CREATE TRIGGER on_user_created AFTER INSERT ON public.users FOR EACH ROW EXECUTE FUNCTION create_wallet_for_new_user();

-- Consultation threshold tracker
CREATE OR REPLACE FUNCTION check_consultation_threshold()
RETURNS TRIGGER AS $$
DECLARE
  v_consultation consultations%ROWTYPE;
  v_msg_count INTEGER;
  v_elapsed_minutes DECIMAL;
BEGIN
  SELECT * INTO v_consultation FROM public.consultations WHERE id = NEW.consultation_id;
  SELECT COUNT(*) INTO v_msg_count FROM public.consultation_messages WHERE consultation_id = NEW.consultation_id;
  IF v_consultation.free_start_at IS NOT NULL THEN
    v_elapsed_minutes := EXTRACT(EPOCH FROM (NOW() - v_consultation.free_start_at)) / 60;
  ELSE v_elapsed_minutes := 0; END IF;
  IF v_consultation.is_free_threshold_hit THEN NEW.is_free := FALSE; ELSE NEW.is_free := TRUE; END IF;
  IF NOT v_consultation.is_free_threshold_hit THEN
    IF v_msg_count >= 10 OR v_elapsed_minutes >= 10 THEN
      UPDATE public.consultations SET is_free_threshold_hit = TRUE, free_ended_at = NOW(),
        status = 'free_threshold_reached', updated_at = NOW() WHERE id = NEW.consultation_id;
    END IF;
  END IF;
  RETURN NEW;
END; $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_consultation_message ON public.consultation_messages;
CREATE TRIGGER on_consultation_message BEFORE INSERT ON public.consultation_messages FOR EACH ROW EXECUTE FUNCTION check_consultation_threshold();

-- Post like counters
CREATE OR REPLACE FUNCTION increment_post_like() RETURNS TRIGGER AS $$
BEGIN UPDATE public.knowledge_posts SET likes_count = likes_count + 1 WHERE id = NEW.post_id; RETURN NEW; END; $$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS on_post_like ON public.knowledge_post_likes;
CREATE TRIGGER on_post_like AFTER INSERT ON public.knowledge_post_likes FOR EACH ROW EXECUTE FUNCTION increment_post_like();

CREATE OR REPLACE FUNCTION decrement_post_like() RETURNS TRIGGER AS $$
BEGIN UPDATE public.knowledge_posts SET likes_count = GREATEST(0, likes_count - 1) WHERE id = OLD.post_id; RETURN OLD; END; $$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS on_post_unlike ON public.knowledge_post_likes;
CREATE TRIGGER on_post_unlike AFTER DELETE ON public.knowledge_post_likes FOR EACH ROW EXECUTE FUNCTION decrement_post_like();

-- Course enrollment counter
CREATE OR REPLACE FUNCTION increment_course_enrolled() RETURNS TRIGGER AS $$
BEGIN UPDATE courses SET enrolled_count = enrolled_count + 1 WHERE id = NEW.course_id; RETURN NEW; END; $$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS on_course_enrollment ON public.course_enrollments;
CREATE TRIGGER on_course_enrollment AFTER INSERT ON public.course_enrollments FOR EACH ROW EXECUTE FUNCTION increment_course_enrolled();

-- ================================================================
-- ROW LEVEL SECURITY (safe re-run — drop policies first)
-- ================================================================
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
ALTER TABLE public.marketplace_listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.escrow_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.saved_listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.market_prices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consultations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consultation_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transport_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transport_bids ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.knowledge_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.knowledge_post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.knowledge_post_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.course_sections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.course_lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.course_enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lesson_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.forum_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.forum_answers ENABLE ROW LEVEL SECURITY;

-- Drop all policies before recreating
DO $$ DECLARE r RECORD;
BEGIN
  FOR r IN SELECT policyname, tablename FROM pg_policies WHERE schemaname = 'public' LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', r.policyname, r.tablename);
  END LOOP;
END $$;

-- Users
CREATE POLICY "Users can view all profiles" ON public.users FOR SELECT USING (TRUE);
CREATE POLICY "Users can update own profile" ON public.users FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON public.users FOR INSERT WITH CHECK (auth.uid() = id);

-- Wallets
CREATE POLICY "Users can view own wallet" ON public.wallets FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can view own transactions" ON public.wallet_transactions FOR SELECT USING (auth.uid() = user_id);

-- Notifications
CREATE POLICY "Users see own notifications" ON public.notifications FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users update own notifications" ON public.notifications FOR UPDATE USING (auth.uid() = user_id);

-- Role profiles
CREATE POLICY "Farmers own profile" ON public.farmer_profiles FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Business own profile" ON public.business_profiles FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Drivers own profile" ON public.driver_profiles FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Experts own profile" ON public.expert_profiles FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Public view verified experts" ON public.expert_profiles FOR SELECT USING (verification_status = 'approved');
CREATE POLICY "Enthusiasts own profile" ON public.enthusiast_profiles FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users submit verifications" ON public.verifications FOR ALL USING (auth.uid() = user_id);

-- Reviews
CREATE POLICY "Public can view reviews" ON public.reviews FOR SELECT USING (TRUE);
CREATE POLICY "Auth users create reviews" ON public.reviews FOR INSERT WITH CHECK (auth.uid() = reviewer_id);

-- Marketplace
CREATE POLICY "Anyone can view active listings" ON public.marketplace_listings FOR SELECT USING (status = 'active');
CREATE POLICY "Sellers manage own listings" ON public.marketplace_listings FOR ALL USING (auth.uid() = seller_id);
CREATE POLICY "Buyers view own orders" ON public.orders FOR SELECT USING (auth.uid() = buyer_id OR auth.uid() = seller_id);
CREATE POLICY "Buyers create orders" ON public.orders FOR INSERT WITH CHECK (auth.uid() = buyer_id);
CREATE POLICY "Order parties update orders" ON public.orders FOR UPDATE USING (auth.uid() = buyer_id OR auth.uid() = seller_id);
CREATE POLICY "Order items visible to parties" ON public.order_items FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.orders o WHERE o.id = order_id AND (o.buyer_id = auth.uid() OR o.seller_id = auth.uid()))
);
CREATE POLICY "Order items insert by buyer" ON public.order_items FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM public.orders o WHERE o.id = order_id AND o.buyer_id = auth.uid())
);
CREATE POLICY "Escrow visible to parties" ON public.escrow_records FOR SELECT USING (auth.uid() = buyer_id OR auth.uid() = seller_id);
CREATE POLICY "Users manage own saved" ON public.saved_listings FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Anyone can view market prices" ON public.market_prices FOR SELECT USING (TRUE);

-- Consultations
CREATE POLICY "Consultation parties access" ON public.consultations FOR SELECT USING (auth.uid() = client_id OR auth.uid() = expert_id);
CREATE POLICY "Clients create consultations" ON public.consultations FOR INSERT WITH CHECK (auth.uid() = client_id);
CREATE POLICY "Consultation parties update" ON public.consultations FOR UPDATE USING (auth.uid() = client_id OR auth.uid() = expert_id);
CREATE POLICY "Messages visible to parties" ON public.consultation_messages FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.consultations c WHERE c.id = consultation_id AND (c.client_id = auth.uid() OR c.expert_id = auth.uid()))
);
CREATE POLICY "Messages sent by participants" ON public.consultation_messages FOR INSERT WITH CHECK (
  auth.uid() = sender_id AND EXISTS (
    SELECT 1 FROM public.consultations c WHERE c.id = consultation_id AND (c.client_id = auth.uid() OR c.expert_id = auth.uid())
  )
);

-- Transport
CREATE POLICY "Anyone views open jobs" ON public.transport_jobs FOR SELECT USING (TRUE);
CREATE POLICY "Posters manage own jobs" ON public.transport_jobs FOR ALL USING (auth.uid() = poster_id);
CREATE POLICY "Drivers view bids" ON public.transport_bids FOR SELECT USING (TRUE);
CREATE POLICY "Drivers place bids" ON public.transport_bids FOR INSERT WITH CHECK (auth.uid() = driver_id);
CREATE POLICY "Drivers update own bids" ON public.transport_bids FOR UPDATE USING (auth.uid() = driver_id);

-- Knowledge
CREATE POLICY "Published posts visible" ON public.knowledge_posts FOR SELECT USING (status = 'published');
CREATE POLICY "Authors manage own posts" ON public.knowledge_posts FOR ALL USING (auth.uid() = author_id);
CREATE POLICY "Auth users like posts" ON public.knowledge_post_likes FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Anyone view comments" ON public.knowledge_post_comments FOR SELECT USING (TRUE);
CREATE POLICY "Auth users add comments" ON public.knowledge_post_comments FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Published courses visible" ON public.courses FOR SELECT USING (status = 'published');
CREATE POLICY "Instructors manage own courses" ON public.courses FOR ALL USING (auth.uid() = instructor_id);
CREATE POLICY "Course sections visible" ON public.course_sections FOR SELECT USING (TRUE);
CREATE POLICY "Lessons visible to enrolled" ON public.course_lessons FOR SELECT USING (
  is_preview = TRUE OR
  EXISTS (SELECT 1 FROM public.course_enrollments e WHERE e.course_id = course_id AND e.user_id = auth.uid() AND e.payment_status = 'paid') OR
  EXISTS (SELECT 1 FROM public.courses c WHERE c.id = course_id AND c.instructor_id = auth.uid())
);
CREATE POLICY "Enrollments visible to user" ON public.course_enrollments FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users enroll" ON public.course_enrollments FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Progress visible to user" ON public.lesson_progress FOR ALL USING (
  EXISTS (SELECT 1 FROM public.course_enrollments e WHERE e.id = enrollment_id AND e.user_id = auth.uid())
);
CREATE POLICY "Forum posts visible" ON public.forum_posts FOR SELECT USING (status = 'published');
CREATE POLICY "Auth users post forum" ON public.forum_posts FOR INSERT WITH CHECK (auth.uid() = author_id);
CREATE POLICY "Forum answers visible" ON public.forum_answers FOR SELECT USING (TRUE);
CREATE POLICY "Auth users answer" ON public.forum_answers FOR INSERT WITH CHECK (auth.uid() = author_id);

-- ================================================================
-- INDEXES (safe re-run)
-- ================================================================
CREATE INDEX IF NOT EXISTS idx_users_roles ON public.users USING GIN (roles);
CREATE INDEX IF NOT EXISTS idx_users_region ON public.users (region);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON public.notifications (user_id, is_read, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_user ON public.wallet_transactions (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_expert_profiles_status ON public.expert_profiles (verification_status);
CREATE INDEX IF NOT EXISTS idx_reviews_reviewee ON public.reviews (reviewee_id);
CREATE INDEX IF NOT EXISTS idx_listings_seller ON public.marketplace_listings (seller_id);
CREATE INDEX IF NOT EXISTS idx_listings_category ON public.marketplace_listings (category, status);
CREATE INDEX IF NOT EXISTS idx_listings_region ON public.marketplace_listings (region, status);
CREATE INDEX IF NOT EXISTS idx_orders_buyer ON public.orders (buyer_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_seller ON public.orders (seller_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_market_prices_commodity ON public.market_prices (commodity, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_consultations_client ON public.consultations (client_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_consultations_expert ON public.consultations (expert_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_consultation_messages ON public.consultation_messages (consultation_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_transport_jobs_status ON public.transport_jobs (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_transport_jobs_region ON public.transport_jobs (pickup_region, status);
CREATE INDEX IF NOT EXISTS idx_transport_bids_job ON public.transport_bids (job_id);
CREATE INDEX IF NOT EXISTS idx_transport_bids_driver ON public.transport_bids (driver_id);
CREATE INDEX IF NOT EXISTS idx_knowledge_posts_status ON public.knowledge_posts (status, published_at DESC);
CREATE INDEX IF NOT EXISTS idx_courses_status ON public.courses (status, published_at DESC);
CREATE INDEX IF NOT EXISTS idx_enrollments_user ON public.course_enrollments (user_id);

-- ================================================================
-- RPC FUNCTIONS
-- ================================================================
CREATE OR REPLACE FUNCTION add_user_role(p_user_id UUID, p_role TEXT)
RETURNS VOID AS $$
BEGIN
  UPDATE public.users SET roles = array_append(roles, p_role::user_role)
  WHERE id = p_user_id AND NOT (p_role::user_role = ANY(roles));
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION remove_user_role(p_user_id UUID, p_role TEXT)
RETURNS VOID AS $$
BEGIN
  UPDATE public.users SET roles = array_remove(roles, p_role::user_role) WHERE id = p_user_id;
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION increment_listing_views(p_listing_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE marketplace_listings SET views_count = views_count + 1 WHERE id = p_listing_id;
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- Auto-release escrow every hour
SELECT cron.schedule(
  'auto-release-escrow', '0 * * * *',
  $$ UPDATE public.escrow_records
     SET status = 'released', released_at = NOW(), release_triggered_by = 'auto_release', updated_at = NOW()
     WHERE status = 'held' AND auto_release_at <= NOW(); $$
);

-- ================================================================
-- SEED: Ghana market prices (skip if already seeded)
-- ================================================================
INSERT INTO public.market_prices (commodity, unit, price_ghs, market_name, region, source, is_verified)
SELECT * FROM (VALUES
  ('Maize', 'kg', 4.50, 'Kumasi Central Market', 'Ashanti', 'admin', TRUE),
  ('Tomatoes', 'kg', 6.00, 'Makola Market', 'Greater Accra', 'admin', TRUE),
  ('Cassava', 'kg', 2.80, 'Techiman Market', 'Bono East', 'admin', TRUE),
  ('Plantain', 'bunch', 18.00, 'Kumasi Central Market', 'Ashanti', 'admin', TRUE),
  ('Yam', 'kg', 5.50, 'Techiman Market', 'Bono East', 'admin', TRUE),
  ('Cocoa', 'kg', 22.00, 'Takoradi Market', 'Western', 'admin', TRUE),
  ('Rice (Local)', 'kg', 8.50, 'Makola Market', 'Greater Accra', 'admin', TRUE),
  ('Groundnuts', 'kg', 12.00, 'Bolgatanga Market', 'Upper East', 'admin', TRUE),
  ('Onions', 'kg', 7.00, 'Agbogbloshie Market', 'Greater Accra', 'admin', TRUE),
  ('Pepper (Dried)', 'kg', 35.00, 'Kumasi Central Market', 'Ashanti', 'admin', TRUE),
  ('Palm Oil', 'litre', 15.00, 'Kumasi Central Market', 'Ashanti', 'admin', TRUE),
  ('Soybean', 'kg', 6.50, 'Tamale Market', 'Northern', 'admin', TRUE)
) AS v(commodity, unit, price_ghs, market_name, region, source, is_verified)
WHERE NOT EXISTS (SELECT 1 FROM public.market_prices LIMIT 1);

-- ================================================================
-- DONE! All tables, triggers, policies, indexes and seed data created.
-- ================================================================
