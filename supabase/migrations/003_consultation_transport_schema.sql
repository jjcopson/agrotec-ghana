-- ============================================================
-- AGROTECH GHANA
-- Migration 003: Consultations, Transport
-- ============================================================

CREATE TYPE consultation_status AS ENUM (
  'requested',
  'accepted',
  'in_progress',
  'free_threshold_reached',
  'paid',
  'completed',
  'cancelled',
  'expired'
);

CREATE TYPE transport_job_status AS ENUM (
  'open',
  'bidding',
  'assigned',
  'in_transit',
  'delivered',
  'completed',
  'cancelled',
  'disputed'
);

CREATE TYPE bid_status AS ENUM (
  'pending',
  'accepted',
  'rejected',
  'withdrawn'
);

-- ============================================================
-- CONSULTATIONS
-- ============================================================

CREATE TABLE public.consultations (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  client_id             UUID NOT NULL REFERENCES public.users(id),
  expert_id             UUID NOT NULL REFERENCES public.users(id),
  expert_profile_id     UUID NOT NULL REFERENCES public.expert_profiles(id),
  status                consultation_status NOT NULL DEFAULT 'requested',
  topic                 TEXT NOT NULL,
  description           TEXT,
  session_price_ghs     DECIMAL(10,2) NOT NULL DEFAULT 0,
  platform_fee_ghs      DECIMAL(10,2) NOT NULL DEFAULT 0,    -- 5%
  expert_earnings_ghs   DECIMAL(10,2) NOT NULL DEFAULT 0,    -- 95%
  -- Free threshold tracking
  message_count         INTEGER NOT NULL DEFAULT 0,
  is_free_threshold_hit BOOLEAN NOT NULL DEFAULT FALSE,
  free_ended_at         TIMESTAMPTZ,
  -- Session timing
  free_start_at         TIMESTAMPTZ,
  paid_start_at         TIMESTAMPTZ,
  ended_at              TIMESTAMPTZ,
  duration_minutes      INTEGER,
  -- Payment
  payment_status        TEXT NOT NULL DEFAULT 'unpaid',     -- 'unpaid','paid','refunded'
  paystack_ref          TEXT,
  payment_method        TEXT,
  -- Scheduling
  scheduled_at          TIMESTAMPTZ,
  accepted_at           TIMESTAMPTZ,
  cancelled_at          TIMESTAMPTZ,
  cancel_reason         TEXT,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.consultation_messages (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  consultation_id UUID NOT NULL REFERENCES public.consultations(id) ON DELETE CASCADE,
  sender_id       UUID NOT NULL REFERENCES public.users(id),
  content         TEXT NOT NULL,
  message_type    TEXT NOT NULL DEFAULT 'text',   -- 'text','image','file','voice'
  media_url       TEXT,
  is_free         BOOLEAN NOT NULL DEFAULT TRUE,  -- TRUE if within free threshold
  is_read         BOOLEAN NOT NULL DEFAULT FALSE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Function: track message count and flip threshold
CREATE OR REPLACE FUNCTION check_consultation_threshold()
RETURNS TRIGGER AS $$
DECLARE
  v_consultation consultations%ROWTYPE;
  v_msg_count INTEGER;
  v_elapsed_minutes DECIMAL;
BEGIN
  SELECT * INTO v_consultation FROM public.consultations WHERE id = NEW.consultation_id;

  -- Count all messages (sent + received)
  SELECT COUNT(*) INTO v_msg_count
  FROM public.consultation_messages
  WHERE consultation_id = NEW.consultation_id;

  -- Calculate elapsed minutes since session started
  IF v_consultation.free_start_at IS NOT NULL THEN
    v_elapsed_minutes := EXTRACT(EPOCH FROM (NOW() - v_consultation.free_start_at)) / 60;
  ELSE
    v_elapsed_minutes := 0;
  END IF;

  -- Mark new message as free or paid
  IF v_consultation.is_free_threshold_hit THEN
    NEW.is_free := FALSE;
  ELSE
    NEW.is_free := TRUE;
  END IF;

  -- Check thresholds (10 messages OR 10 minutes)
  IF NOT v_consultation.is_free_threshold_hit THEN
    IF v_msg_count >= 10 OR v_elapsed_minutes >= 10 THEN
      UPDATE public.consultations
      SET 
        is_free_threshold_hit = TRUE,
        free_ended_at = NOW(),
        status = 'free_threshold_reached',
        updated_at = NOW()
      WHERE id = NEW.consultation_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_consultation_message
  BEFORE INSERT ON public.consultation_messages
  FOR EACH ROW EXECUTE FUNCTION check_consultation_threshold();

-- ============================================================
-- TRANSPORT JOBS
-- ============================================================

CREATE TABLE public.transport_jobs (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  poster_id           UUID NOT NULL REFERENCES public.users(id),
  assigned_driver_id  UUID REFERENCES public.users(id),
  status              transport_job_status NOT NULL DEFAULT 'open',
  title               TEXT NOT NULL,
  description         TEXT,
  cargo_type          TEXT NOT NULL,
  cargo_weight_kg     DECIMAL(10,2),
  cargo_volume_m3     DECIMAL(10,2),
  cargo_images        TEXT[],
  -- Pickup
  pickup_address      TEXT NOT NULL,
  pickup_region       TEXT NOT NULL,
  pickup_lat          DOUBLE PRECISION,
  pickup_lng          DOUBLE PRECISION,
  pickup_date         DATE NOT NULL,
  -- Delivery
  delivery_address    TEXT NOT NULL,
  delivery_region     TEXT NOT NULL,
  delivery_lat        DOUBLE PRECISION,
  delivery_lng        DOUBLE PRECISION,
  -- Budget
  budget_ghs          DECIMAL(10,2),
  agreed_price_ghs    DECIMAL(10,2),
  platform_fee_ghs    DECIMAL(10,2) DEFAULT 0,
  -- Status timestamps
  assigned_at         TIMESTAMPTZ,
  pickup_at           TIMESTAMPTZ,
  delivered_at        TIMESTAMPTZ,
  completed_at        TIMESTAMPTZ,
  cancelled_at        TIMESTAMPTZ,
  cancel_reason       TEXT,
  dispute_reason      TEXT,
  disputed_at         TIMESTAMPTZ,
  -- Payment
  payment_status      TEXT NOT NULL DEFAULT 'unpaid',
  paystack_ref        TEXT,
  payment_method      TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.transport_bids (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  job_id          UUID NOT NULL REFERENCES public.transport_jobs(id) ON DELETE CASCADE,
  driver_id       UUID NOT NULL REFERENCES public.users(id),
  bid_amount_ghs  DECIMAL(10,2) NOT NULL,
  message         TEXT,
  estimated_days  INTEGER,
  status          bid_status NOT NULL DEFAULT 'pending',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(job_id, driver_id)
);

-- ============================================================
-- TRIGGERS
-- ============================================================

CREATE TRIGGER consultations_updated_at BEFORE UPDATE ON public.consultations FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER transport_jobs_updated_at BEFORE UPDATE ON public.transport_jobs FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER transport_bids_updated_at BEFORE UPDATE ON public.transport_bids FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- RLS
-- ============================================================

ALTER TABLE public.consultations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consultation_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transport_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transport_bids ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Consultation parties access" ON public.consultations FOR SELECT
  USING (auth.uid() = client_id OR auth.uid() = expert_id);
CREATE POLICY "Clients create consultations" ON public.consultations FOR INSERT
  WITH CHECK (auth.uid() = client_id);
CREATE POLICY "Consultation parties update" ON public.consultations FOR UPDATE
  USING (auth.uid() = client_id OR auth.uid() = expert_id);

CREATE POLICY "Messages visible to parties" ON public.consultation_messages FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM public.consultations c
    WHERE c.id = consultation_id AND (c.client_id = auth.uid() OR c.expert_id = auth.uid())
  ));
CREATE POLICY "Messages sent by participants" ON public.consultation_messages FOR INSERT
  WITH CHECK (auth.uid() = sender_id AND EXISTS (
    SELECT 1 FROM public.consultations c
    WHERE c.id = consultation_id AND (c.client_id = auth.uid() OR c.expert_id = auth.uid())
  ));

CREATE POLICY "Anyone views open jobs" ON public.transport_jobs FOR SELECT USING (TRUE);
CREATE POLICY "Posters manage own jobs" ON public.transport_jobs FOR ALL USING (auth.uid() = poster_id);
CREATE POLICY "Drivers view and bid" ON public.transport_bids FOR SELECT USING (TRUE);
CREATE POLICY "Drivers place bids" ON public.transport_bids FOR INSERT WITH CHECK (auth.uid() = driver_id);
CREATE POLICY "Drivers update own bids" ON public.transport_bids FOR UPDATE USING (auth.uid() = driver_id);

-- Indexes
CREATE INDEX idx_consultations_client ON public.consultations (client_id, created_at DESC);
CREATE INDEX idx_consultations_expert ON public.consultations (expert_id, created_at DESC);
CREATE INDEX idx_consultations_status ON public.consultations (status);
CREATE INDEX idx_consultation_messages ON public.consultation_messages (consultation_id, created_at ASC);
CREATE INDEX idx_transport_jobs_status ON public.transport_jobs (status, created_at DESC);
CREATE INDEX idx_transport_jobs_region ON public.transport_jobs (pickup_region, status);
CREATE INDEX idx_transport_bids_job ON public.transport_bids (job_id);
CREATE INDEX idx_transport_bids_driver ON public.transport_bids (driver_id);
