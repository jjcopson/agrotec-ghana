-- ============================================================
-- AGROTECH GHANA — MARKETPLACE SCHEMA
-- Migration 002: Listings, Orders, Escrow
-- ============================================================

CREATE TYPE listing_status AS ENUM (
  'draft', 'active', 'sold_out', 'suspended', 'deleted'
);

CREATE TYPE listing_category AS ENUM (
  'crops', 'livestock', 'equipment', 'inputs', 'processed_goods',
  'seeds', 'fertilizers', 'pesticides', 'irrigation', 'other'
);

CREATE TYPE order_status AS ENUM (
  'pending_payment',
  'paid',
  'processing',
  'shipped',
  'delivered',
  'completed',
  'disputed',
  'refunded',
  'cancelled'
);

CREATE TYPE escrow_status AS ENUM (
  'held',
  'released',
  'refunded',
  'disputed'
);

-- ============================================================
-- MARKETPLACE LISTINGS
-- ============================================================

CREATE TABLE public.marketplace_listings (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  seller_id       UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  title           TEXT NOT NULL,
  description     TEXT,
  category        listing_category NOT NULL,
  subcategory     TEXT,
  price_ghs       DECIMAL(15,2) NOT NULL,
  unit            TEXT NOT NULL DEFAULT 'kg',    -- kg, bag, crate, piece, litre
  quantity        DECIMAL(15,2) NOT NULL,
  quantity_available DECIMAL(15,2) NOT NULL,
  images          TEXT[] NOT NULL DEFAULT '{}',
  location        TEXT,
  region          TEXT,
  district        TEXT,
  lat             DOUBLE PRECISION,
  lng             DOUBLE PRECISION,
  tags            TEXT[],
  status          listing_status NOT NULL DEFAULT 'active',
  views_count     INTEGER NOT NULL DEFAULT 0,
  is_negotiable   BOOLEAN NOT NULL DEFAULT FALSE,
  delivery_available BOOLEAN NOT NULL DEFAULT FALSE,
  pickup_available   BOOLEAN NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- ORDERS
-- ============================================================

CREATE TABLE public.orders (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  buyer_id        UUID NOT NULL REFERENCES public.users(id),
  seller_id       UUID NOT NULL REFERENCES public.users(id),
  status          order_status NOT NULL DEFAULT 'pending_payment',
  subtotal_ghs    DECIMAL(15,2) NOT NULL,
  delivery_fee_ghs DECIMAL(15,2) NOT NULL DEFAULT 0,
  platform_fee_ghs DECIMAL(15,2) NOT NULL DEFAULT 0,
  total_ghs       DECIMAL(15,2) NOT NULL,
  delivery_address TEXT,
  delivery_region TEXT,
  delivery_lat    DOUBLE PRECISION,
  delivery_lng    DOUBLE PRECISION,
  notes           TEXT,
  paystack_ref    TEXT,
  payment_method  TEXT,              -- 'wallet', 'momo', 'card'
  dispute_reason  TEXT,
  disputed_at     TIMESTAMPTZ,
  delivered_at    TIMESTAMPTZ,
  completed_at    TIMESTAMPTZ,
  cancelled_at    TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.order_items (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id        UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  listing_id      UUID NOT NULL REFERENCES public.marketplace_listings(id),
  quantity        DECIMAL(15,2) NOT NULL,
  unit_price_ghs  DECIMAL(15,2) NOT NULL,
  total_price_ghs DECIMAL(15,2) NOT NULL,
  snapshot        JSONB          -- snapshot of listing at time of purchase
);

-- ============================================================
-- ESCROW
-- ============================================================

CREATE TABLE public.escrow_records (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id        UUID UNIQUE NOT NULL REFERENCES public.orders(id),
  buyer_id        UUID NOT NULL REFERENCES public.users(id),
  seller_id       UUID NOT NULL REFERENCES public.users(id),
  amount_ghs      DECIMAL(15,2) NOT NULL,
  platform_fee_ghs DECIMAL(15,2) NOT NULL DEFAULT 0,
  status          escrow_status NOT NULL DEFAULT 'held',
  held_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  auto_release_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '3 days'),
  released_at     TIMESTAMPTZ,
  release_triggered_by TEXT,     -- 'buyer_confirm' | 'auto_release' | 'admin'
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- AUTO-RELEASE ESCROW (pg_cron job — runs every hour)
-- ============================================================

SELECT cron.schedule(
  'auto-release-escrow',
  '0 * * * *',
  $$
    UPDATE public.escrow_records
    SET 
      status = 'released',
      released_at = NOW(),
      release_triggered_by = 'auto_release',
      updated_at = NOW()
    WHERE 
      status = 'held'
      AND auto_release_at <= NOW();
  $$
);

-- ============================================================
-- WISHLIST / SAVED LISTINGS
-- ============================================================

CREATE TABLE public.saved_listings (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  listing_id  UUID NOT NULL REFERENCES public.marketplace_listings(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, listing_id)
);

-- ============================================================
-- MARKET PRICES (commodity price board)
-- ============================================================

CREATE TABLE public.market_prices (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  commodity     TEXT NOT NULL,
  unit          TEXT NOT NULL DEFAULT 'kg',
  price_ghs     DECIMAL(10,2) NOT NULL,
  market_name   TEXT,
  region        TEXT,
  source        TEXT,            -- 'admin', 'mofa', 'user_submitted'
  submitted_by  UUID REFERENCES public.users(id),
  is_verified   BOOLEAN NOT NULL DEFAULT FALSE,
  recorded_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TRIGGERS
-- ============================================================

CREATE TRIGGER marketplace_listings_updated_at BEFORE UPDATE ON public.marketplace_listings FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER orders_updated_at BEFORE UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER escrow_records_updated_at BEFORE UPDATE ON public.escrow_records FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- RLS
-- ============================================================

ALTER TABLE public.marketplace_listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.escrow_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.saved_listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.market_prices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view active listings" ON public.marketplace_listings FOR SELECT USING (status = 'active');
CREATE POLICY "Sellers manage own listings" ON public.marketplace_listings FOR ALL USING (auth.uid() = seller_id);
CREATE POLICY "Buyers view own orders" ON public.orders FOR SELECT USING (auth.uid() = buyer_id OR auth.uid() = seller_id);
CREATE POLICY "Buyers create orders" ON public.orders FOR INSERT WITH CHECK (auth.uid() = buyer_id);
CREATE POLICY "Order parties update orders" ON public.orders FOR UPDATE USING (auth.uid() = buyer_id OR auth.uid() = seller_id);
CREATE POLICY "Order items visible to parties" ON public.order_items FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.orders o WHERE o.id = order_id AND (o.buyer_id = auth.uid() OR o.seller_id = auth.uid()))
);
CREATE POLICY "Escrow visible to parties" ON public.escrow_records FOR SELECT USING (auth.uid() = buyer_id OR auth.uid() = seller_id);
CREATE POLICY "Users manage own saved" ON public.saved_listings FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Anyone can view market prices" ON public.market_prices FOR SELECT USING (TRUE);

-- Indexes
CREATE INDEX idx_listings_seller ON public.marketplace_listings (seller_id);
CREATE INDEX idx_listings_category ON public.marketplace_listings (category, status);
CREATE INDEX idx_listings_region ON public.marketplace_listings (region, status);
CREATE INDEX idx_orders_buyer ON public.orders (buyer_id, created_at DESC);
CREATE INDEX idx_orders_seller ON public.orders (seller_id, created_at DESC);
CREATE INDEX idx_escrow_auto_release ON public.escrow_records (status, auto_release_at) WHERE status = 'held';
CREATE INDEX idx_market_prices_commodity ON public.market_prices (commodity, recorded_at DESC);
