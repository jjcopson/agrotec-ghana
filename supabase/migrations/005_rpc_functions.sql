-- ============================================================
-- AGROTECH GHANA
-- Migration 005: RPC Helper Functions
-- ============================================================

-- Add a role to user (append to array if not already there)
CREATE OR REPLACE FUNCTION add_user_role(p_user_id UUID, p_role TEXT)
RETURNS VOID AS $$
BEGIN
  UPDATE public.users
  SET roles = array_append(roles, p_role::user_role)
  WHERE id = p_user_id
    AND NOT (p_role::user_role = ANY(roles));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Remove a role from user
CREATE OR REPLACE FUNCTION remove_user_role(p_user_id UUID, p_role TEXT)
RETURNS VOID AS $$
BEGIN
  UPDATE public.users
  SET roles = array_remove(roles, p_role::user_role)
  WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update expert rating after new review
CREATE OR REPLACE FUNCTION update_expert_rating()
RETURNS TRIGGER AS $$
DECLARE
  v_avg DECIMAL(3,2);
  v_count INTEGER;
  v_user_id UUID;
BEGIN
  -- Get expert user_id from expert_profiles
  IF NEW.reference_type = 'consultation' THEN
    SELECT c.expert_id INTO v_user_id
    FROM consultations c
    WHERE c.id = NEW.reference_id;

    SELECT AVG(rating)::DECIMAL(3,2), COUNT(*)
    INTO v_avg, v_count
    FROM reviews
    WHERE reviewee_id = NEW.reviewee_id
      AND reference_type = 'consultation';

    UPDATE expert_profiles
    SET rating = v_avg,
        total_consultations = v_count
    WHERE user_id = NEW.reviewee_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_review_insert
  AFTER INSERT ON public.reviews
  FOR EACH ROW EXECUTE FUNCTION update_expert_rating();

-- Update driver rating after transport review
CREATE OR REPLACE FUNCTION update_driver_rating()
RETURNS TRIGGER AS $$
DECLARE
  v_avg DECIMAL(3,2);
  v_count INTEGER;
BEGIN
  IF NEW.reference_type = 'transport' THEN
    SELECT AVG(rating)::DECIMAL(3,2), COUNT(*)
    INTO v_avg, v_count
    FROM reviews
    WHERE reviewee_id = NEW.reviewee_id
      AND reference_type = 'transport';

    UPDATE driver_profiles
    SET rating = v_avg,
        total_trips = total_trips + 1
    WHERE user_id = NEW.reviewee_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_transport_review
  AFTER INSERT ON public.reviews
  FOR EACH ROW EXECUTE FUNCTION update_driver_rating();

-- Increment course enrolled count
CREATE OR REPLACE FUNCTION increment_course_enrolled()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE courses
  SET enrolled_count = enrolled_count + 1
  WHERE id = NEW.course_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_course_enrollment
  AFTER INSERT ON public.course_enrollments
  FOR EACH ROW EXECUTE FUNCTION increment_course_enrolled();

-- Get marketplace listing view count increment
CREATE OR REPLACE FUNCTION increment_listing_views(p_listing_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE marketplace_listings
  SET views_count = views_count + 1
  WHERE id = p_listing_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Marketplace: hold buyer payment in escrow
CREATE OR REPLACE FUNCTION process_marketplace_order(
  p_order_id UUID,
  p_buyer_id UUID,
  p_seller_id UUID,
  p_amount_ghs DECIMAL,
  p_platform_fee_ghs DECIMAL
)
RETURNS VOID AS $$
DECLARE
  v_buyer_wallet wallets%ROWTYPE;
BEGIN
  SELECT * INTO v_buyer_wallet FROM wallets WHERE user_id = p_buyer_id FOR UPDATE;

  IF v_buyer_wallet.balance_ghs < p_amount_ghs THEN
    RAISE EXCEPTION 'Insufficient balance';
  END IF;

  -- Deduct from buyer
  UPDATE wallets
  SET balance_ghs = balance_ghs - p_amount_ghs,
      escrow_balance = escrow_balance + (p_amount_ghs - p_platform_fee_ghs)
  WHERE user_id = p_buyer_id;

  -- Update order status
  UPDATE orders SET status = 'paid' WHERE id = p_order_id;

  -- Create escrow record
  INSERT INTO escrow_records (
    order_id, buyer_id, seller_id,
    amount_ghs, platform_fee_ghs,
    status, held_at, auto_release_at
  ) VALUES (
    p_order_id, p_buyer_id, p_seller_id,
    p_amount_ghs - p_platform_fee_ghs,
    p_platform_fee_ghs,
    'held', NOW(),
    NOW() + INTERVAL '3 days'
  );

  -- Record buyer debit transaction
  INSERT INTO wallet_transactions (
    wallet_id, user_id, type, amount_ghs, fee_ghs,
    reference_type, reference_id, description, status
  ) VALUES (
    v_buyer_wallet.id, p_buyer_id, 'debit',
    p_amount_ghs, p_platform_fee_ghs,
    'marketplace_payment', p_order_id,
    'Marketplace purchase (held in escrow)', 'completed'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
