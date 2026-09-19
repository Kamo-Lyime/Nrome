-- =====================================================
-- NEW PRICING STRUCTURE - DATABASE SCHEMA UPDATES
-- =====================================================

-- 1. Add Verification Badge columns to practitioners table
ALTER TABLE practitioners 
ADD COLUMN IF NOT EXISTS verified_badge BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS badge_purchased_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS badge_payment_reference TEXT,
ADD COLUMN IF NOT EXISTS medical_aid_fee_balance INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS can_accept_bookings BOOLEAN DEFAULT true;

-- 2. Create verification_badge_payments table
CREATE TABLE IF NOT EXISTS verification_badge_payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    practitioner_id UUID REFERENCES practitioners(id) ON DELETE CASCADE,
    amount INTEGER NOT NULL DEFAULT 14900, -- R149.00 in cents
    payment_reference TEXT NOT NULL,
    payment_status TEXT DEFAULT 'pending',
    paystack_reference TEXT,
    paid_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Create medical_aid_fees table (tracks R10 fees per booking)
CREATE TABLE IF NOT EXISTS medical_aid_fees (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    practitioner_id UUID REFERENCES practitioners(id) ON DELETE CASCADE,
    appointment_id UUID, -- future: link to appointments table
    amount INTEGER NOT NULL DEFAULT 1000, -- R10.00 in cents
    payment_status TEXT DEFAULT 'pending', -- pending, paid, waived
    payment_reference TEXT,
    paystack_reference TEXT,
    booking_date TIMESTAMPTZ,
    paid_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Create platform_fees table (tracks all 5% fees)
CREATE TABLE IF NOT EXISTS platform_fees (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    practitioner_id UUID REFERENCES practitioners(id) ON DELETE CASCADE,
    appointment_id UUID,
    consultation_fee INTEGER NOT NULL, -- in cents
    platform_fee_percentage DECIMAL(5,2) DEFAULT 5.00,
    platform_fee_amount INTEGER NOT NULL, -- calculated 5% in cents
    payment_reference TEXT,
    payment_status TEXT DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- RLS POLICIES
-- =====================================================

-- Enable RLS
ALTER TABLE verification_badge_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE medical_aid_fees ENABLE ROW LEVEL SECURITY;
ALTER TABLE platform_fees ENABLE ROW LEVEL SECURITY;

-- Verification Badge Payments Policies
DROP POLICY IF EXISTS "Practitioners can view own badge payments" ON verification_badge_payments;
CREATE POLICY "Practitioners can view own badge payments"
    ON verification_badge_payments FOR SELECT
    USING (practitioner_id IN (
        SELECT id FROM practitioners WHERE user_id = auth.uid()
    ));

DROP POLICY IF EXISTS "Practitioners can insert own badge payments" ON verification_badge_payments;
CREATE POLICY "Practitioners can insert own badge payments"
    ON verification_badge_payments FOR INSERT
    WITH CHECK (practitioner_id IN (
        SELECT id FROM practitioners WHERE user_id = auth.uid()
    ));

DROP POLICY IF EXISTS "Admins can view all badge payments" ON verification_badge_payments;
CREATE POLICY "Admins can view all badge payments"
    ON verification_badge_payments FOR ALL
    USING (true); -- Simplified for now, add admin check later

-- Medical Aid Fees Policies
DROP POLICY IF EXISTS "Practitioners can view own medical aid fees" ON medical_aid_fees;
CREATE POLICY "Practitioners can view own medical aid fees"
    ON medical_aid_fees FOR SELECT
    USING (practitioner_id IN (
        SELECT id FROM practitioners WHERE user_id = auth.uid()
    ));

DROP POLICY IF EXISTS "Practitioners can update own medical aid fees" ON medical_aid_fees;
CREATE POLICY "Practitioners can update own medical aid fees"
    ON medical_aid_fees FOR UPDATE
    USING (practitioner_id IN (
        SELECT id FROM practitioners WHERE user_id = auth.uid()
    ));

DROP POLICY IF EXISTS "System can insert medical aid fees" ON medical_aid_fees;
CREATE POLICY "System can insert medical aid fees"
    ON medical_aid_fees FOR INSERT
    WITH CHECK (true); -- Anyone authenticated can create

-- Platform Fees Policies
DROP POLICY IF EXISTS "Practitioners can view own platform fees" ON platform_fees;
CREATE POLICY "Practitioners can view own platform fees"
    ON platform_fees FOR SELECT
    USING (practitioner_id IN (
        SELECT id FROM practitioners WHERE user_id = auth.uid()
    ));

DROP POLICY IF EXISTS "System can insert platform fees" ON platform_fees;
CREATE POLICY "System can insert platform fees"
    ON platform_fees FOR INSERT
    WITH CHECK (true);

-- =====================================================
-- HELPER FUNCTIONS
-- =====================================================

-- Function to check if practitioner can accept bookings
CREATE OR REPLACE FUNCTION can_practitioner_accept_bookings(practitioner_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM practitioners 
        WHERE id = practitioner_uuid 
        AND verification_status = 'verified'
        AND medical_aid_fee_balance = 0
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to add medical aid fee when booking accepted
CREATE OR REPLACE FUNCTION add_medical_aid_fee(practitioner_uuid UUID)
RETURNS UUID AS $$
DECLARE
    fee_id UUID;
BEGIN
    -- Insert new fee record
    INSERT INTO medical_aid_fees (practitioner_id, booking_date)
    VALUES (practitioner_uuid, NOW())
    RETURNING id INTO fee_id;
    
    -- Update practitioner balance
    UPDATE practitioners 
    SET medical_aid_fee_balance = medical_aid_fee_balance + 1000,
        can_accept_bookings = false
    WHERE id = practitioner_uuid;
    
    RETURN fee_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to clear medical aid fee balance
CREATE OR REPLACE FUNCTION clear_medical_aid_fees(practitioner_uuid UUID, payment_ref TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    total_unpaid INTEGER;
BEGIN
    -- Get total unpaid fees
    SELECT COALESCE(SUM(amount), 0) INTO total_unpaid
    FROM medical_aid_fees
    WHERE practitioner_id = practitioner_uuid
    AND payment_status = 'pending';
    
    -- Mark all pending fees as paid
    UPDATE medical_aid_fees
    SET payment_status = 'paid',
        payment_reference = payment_ref,
        paid_at = NOW()
    WHERE practitioner_id = practitioner_uuid
    AND payment_status = 'pending';
    
    -- Reset practitioner balance
    UPDATE practitioners
    SET medical_aid_fee_balance = 0,
        can_accept_bookings = true
    WHERE id = practitioner_uuid;
    
    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to activate verification badge
CREATE OR REPLACE FUNCTION activate_verification_badge(practitioner_uuid UUID, payment_ref TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    -- Update practitioner record
    UPDATE practitioners
    SET verified_badge = true,
        badge_purchased_at = NOW(),
        badge_payment_reference = payment_ref
    WHERE id = practitioner_uuid;
    
    -- Update payment record
    UPDATE verification_badge_payments
    SET payment_status = 'paid',
        paid_at = NOW()
    WHERE practitioner_id = practitioner_uuid
    AND payment_reference = payment_ref;
    
    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_verification_badge_payments_practitioner 
    ON verification_badge_payments(practitioner_id);
    
CREATE INDEX IF NOT EXISTS idx_medical_aid_fees_practitioner 
    ON medical_aid_fees(practitioner_id);
    
CREATE INDEX IF NOT EXISTS idx_medical_aid_fees_status 
    ON medical_aid_fees(payment_status);
    
CREATE INDEX IF NOT EXISTS idx_platform_fees_practitioner 
    ON platform_fees(practitioner_id);
    
CREATE INDEX IF NOT EXISTS idx_practitioners_verified_badge 
    ON practitioners(verified_badge) WHERE verified_badge = true;

-- =====================================================
-- DATA MIGRATION (Optional - for existing practitioners)
-- =====================================================

-- Ensure all existing practitioners can accept bookings by default
UPDATE practitioners 
SET can_accept_bookings = true,
    medical_aid_fee_balance = 0
WHERE can_accept_bookings IS NULL;

-- =====================================================
-- VERIFICATION
-- =====================================================

-- Check that all columns exist
DO $$
BEGIN
    RAISE NOTICE 'Verification Complete:';
    RAISE NOTICE '- Practitioners table updated: %', (
        SELECT COUNT(*) FROM information_schema.columns 
        WHERE table_name = 'practitioners' 
        AND column_name IN ('verified_badge', 'medical_aid_fee_balance', 'can_accept_bookings')
    );
    RAISE NOTICE '- New tables created: %', (
        SELECT COUNT(*) FROM information_schema.tables 
        WHERE table_name IN ('verification_badge_payments', 'medical_aid_fees', 'platform_fees')
    );
END $$;
