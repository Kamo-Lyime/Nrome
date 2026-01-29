-- =====================================================
-- PAYMENT-ENABLED APPOINTMENT BOOKING SYSTEM
-- Integrates Paystack payments with automated workflows
-- =====================================================

-- Enable UUID utilities
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =====================================================
-- 1. ENHANCED APPOINTMENTS TABLE WITH PAYMENT FIELDS
-- =====================================================

-- Drop existing appointments table to recreate with payment fields
DROP TABLE IF EXISTS appointment_logs CASCADE;
DROP TABLE IF EXISTS payment_transactions CASCADE;

-- Add payment-related columns to appointments
ALTER TABLE appointments
    ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'PENDING_PAYMENT' 
        CHECK (status IN (
            'PENDING_PAYMENT', 
            'PAYMENT_FAILED', 
            'PENDING_CONFIRMATION', 
            'CONFIRMED', 
            'COMPLETED', 
            'NO_SHOW', 
            'CANCELLED', 
            'REFUNDED'
        )),
    ADD COLUMN IF NOT EXISTS payment_reference TEXT UNIQUE,
    ADD COLUMN IF NOT EXISTS payment_status TEXT DEFAULT 'pending' 
        CHECK (payment_status IN ('pending', 'success', 'failed', 'refunded')),
    ADD COLUMN IF NOT EXISTS amount_paid NUMERIC(10,2) DEFAULT 500.00,
    ADD COLUMN IF NOT EXISTS currency TEXT DEFAULT 'ZAR',
    ADD COLUMN IF NOT EXISTS platform_fee NUMERIC(10,2) DEFAULT 100.00,
    ADD COLUMN IF NOT EXISTS practitioner_amount NUMERIC(10,2) DEFAULT 400.00,
    ADD COLUMN IF NOT EXISTS paystack_split_code TEXT,
    ADD COLUMN IF NOT EXISTS confirmation_deadline TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS confirmed_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS refund_reference TEXT,
    ADD COLUMN IF NOT EXISTS refunded_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS no_show_checked BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS no_show_fee NUMERIC(10,2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS cancellation_policy TEXT DEFAULT '24h_full_refund',
    ADD COLUMN IF NOT EXISTS cancelled_by TEXT,
    ADD COLUMN IF NOT EXISTS payment_metadata JSONB DEFAULT '{}'::jsonb;

-- Update default status for existing appointments
UPDATE appointments SET status = 'PENDING_PAYMENT' WHERE status = 'pending';

-- Create indexes for payment queries
CREATE INDEX IF NOT EXISTS idx_appointments_status ON appointments(status);
CREATE INDEX IF NOT EXISTS idx_appointments_payment_ref ON appointments(payment_reference);
CREATE INDEX IF NOT EXISTS idx_appointments_confirmation_deadline ON appointments(confirmation_deadline);

-- =====================================================
-- 2. PRACTITIONER SUBACCOUNTS TABLE (Paystack Integration)
-- =====================================================

CREATE TABLE IF NOT EXISTS practitioner_subaccounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    practitioner_id UUID REFERENCES medical_practitioners(id) ON DELETE CASCADE NOT NULL,
    
    -- Paystack subaccount details
    subaccount_code TEXT UNIQUE NOT NULL,
    account_number TEXT NOT NULL,
    bank_code TEXT NOT NULL,
    bank_name TEXT,
    business_name TEXT NOT NULL,
    settlement_bank TEXT,
    percentage_charge NUMERIC(5,2) DEFAULT 80.00, -- Practitioner gets 80%
    
    -- Status tracking
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    last_settlement TIMESTAMPTZ,
    
    -- Metadata
    paystack_metadata JSONB DEFAULT '{}'::jsonb,
    
    UNIQUE(practitioner_id)
);

CREATE INDEX IF NOT EXISTS idx_subaccounts_practitioner ON practitioner_subaccounts(practitioner_id);
CREATE INDEX IF NOT EXISTS idx_subaccounts_code ON practitioner_subaccounts(subaccount_code);

-- Enable RLS
ALTER TABLE practitioner_subaccounts ENABLE ROW LEVEL SECURITY;

-- Policy: Practitioners can view their own subaccount
CREATE POLICY "Practitioners view own subaccount"
ON practitioner_subaccounts
FOR SELECT
USING (
    practitioner_id IN (
        SELECT id FROM medical_practitioners WHERE owner_user_id = auth.uid()
    )
);

-- =====================================================
-- 3. PAYMENT TRANSACTIONS TABLE (Audit Trail)
-- =====================================================

CREATE TABLE IF NOT EXISTS payment_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    appointment_id UUID REFERENCES appointments(id) ON DELETE SET NULL,
    
    -- Paystack transaction details
    reference TEXT UNIQUE NOT NULL,
    paystack_reference TEXT,
    transaction_type TEXT NOT NULL CHECK (transaction_type IN ('payment', 'refund', 'split', 'no_show_fee')),
    
    -- Amount details
    amount NUMERIC(10,2) NOT NULL,
    currency TEXT DEFAULT 'ZAR',
    platform_fee NUMERIC(10,2),
    practitioner_amount NUMERIC(10,2),
    
    -- Status
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'success', 'failed', 'reversed')),
    
    -- Split payment details
    subaccount_code TEXT,
    split_code TEXT,
    
    -- User tracking
    patient_id UUID REFERENCES auth.users(id),
    practitioner_id UUID REFERENCES medical_practitioners(id),
    
    -- Metadata
    paystack_response JSONB DEFAULT '{}'::jsonb,
    webhook_data JSONB DEFAULT '{}'::jsonb,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    failed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_transactions_appointment ON payment_transactions(appointment_id);
CREATE INDEX IF NOT EXISTS idx_transactions_reference ON payment_transactions(reference);
CREATE INDEX IF NOT EXISTS idx_transactions_status ON payment_transactions(status);
CREATE INDEX IF NOT EXISTS idx_transactions_type ON payment_transactions(transaction_type);

-- Enable RLS
ALTER TABLE payment_transactions ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own transactions
CREATE POLICY "Users view own transactions"
ON payment_transactions
FOR SELECT
USING (auth.uid() = patient_id);

-- Policy: Practitioners can view transactions for their appointments
CREATE POLICY "Practitioners view their transactions"
ON payment_transactions
FOR SELECT
USING (
    practitioner_id IN (
        SELECT id FROM medical_practitioners WHERE owner_user_id = auth.uid()
    )
);

-- =====================================================
-- 4. APPOINTMENT LOGS TABLE (Complete Audit Trail)
-- =====================================================

CREATE TABLE IF NOT EXISTS appointment_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    appointment_id UUID REFERENCES appointments(id) ON DELETE CASCADE,
    
    -- Status transition tracking
    old_status TEXT,
    new_status TEXT,
    
    -- Action details
    action TEXT NOT NULL,
    actor TEXT, -- 'patient', 'practitioner', 'system', 'webhook'
    actor_user_id UUID REFERENCES auth.users(id),
    
    -- Additional context
    notes TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Timestamp
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_logs_appointment ON appointment_logs(appointment_id);
CREATE INDEX IF NOT EXISTS idx_logs_created ON appointment_logs(created_at DESC);

-- Enable RLS
ALTER TABLE appointment_logs ENABLE ROW LEVEL SECURITY;

-- Policy: Allow reading logs for appointments user has access to
CREATE POLICY "Users view logs for their appointments"
ON appointment_logs
FOR SELECT
USING (
    appointment_id IN (
        SELECT id FROM appointments WHERE user_id = auth.uid()
    ) OR
    appointment_id IN (
        SELECT a.id FROM appointments a
        JOIN medical_practitioners mp ON a.practitioner_id = mp.id
        WHERE mp.owner_user_id = auth.uid()
    )
);

-- =====================================================
-- 5. HELPER FUNCTIONS
-- =====================================================

-- Function to log appointment status changes
CREATE OR REPLACE FUNCTION log_appointment_change()
RETURNS TRIGGER AS $$
BEGIN
    -- Only log if status changed
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO appointment_logs (
            appointment_id,
            old_status,
            new_status,
            action,
            actor,
            metadata
        ) VALUES (
            NEW.id,
            OLD.status,
            NEW.status,
            'status_change',
            'system',
            jsonb_build_object(
                'timestamp', NOW(),
                'old_payment_status', OLD.payment_status,
                'new_payment_status', NEW.payment_status
            )
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for appointment status changes
DROP TRIGGER IF EXISTS trigger_log_appointment_changes ON appointments;
CREATE TRIGGER trigger_log_appointment_changes
AFTER UPDATE ON appointments
FOR EACH ROW
EXECUTE FUNCTION log_appointment_change();

-- Function to auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for appointments updated_at
DROP TRIGGER IF EXISTS update_appointments_updated_at ON appointments;
CREATE TRIGGER update_appointments_updated_at
BEFORE UPDATE ON appointments
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- Trigger for subaccounts updated_at
DROP TRIGGER IF EXISTS update_subaccounts_updated_at ON practitioner_subaccounts;
CREATE TRIGGER update_subaccounts_updated_at
BEFORE UPDATE ON practitioner_subaccounts
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- 6. VIEWS FOR EASY QUERYING
-- =====================================================

-- View: Pending confirmations (need practitioner action)
CREATE OR REPLACE VIEW pending_confirmations AS
SELECT 
    a.id,
    a.booking_id,
    a.patient_name,
    a.appointment_date,
    a.appointment_time,
    a.amount_paid,
    a.confirmation_deadline,
    mp.name as practitioner_name,
    mp.email_address as practitioner_email
FROM appointments a
JOIN medical_practitioners mp ON a.practitioner_id = mp.id
WHERE a.status = 'PENDING_CONFIRMATION'
AND a.confirmation_deadline > NOW()
ORDER BY a.confirmation_deadline ASC;

-- View: Overdue confirmations (need auto-refund)
CREATE OR REPLACE VIEW overdue_confirmations AS
SELECT 
    a.id,
    a.booking_id,
    a.payment_reference,
    a.amount_paid,
    a.confirmation_deadline,
    a.patient_email
FROM appointments a
WHERE a.status = 'PENDING_CONFIRMATION'
AND a.confirmation_deadline <= NOW()
ORDER BY a.confirmation_deadline ASC;

-- View: Upcoming appointments (check for no-shows)
CREATE OR REPLACE VIEW upcoming_appointments AS
SELECT 
    a.id,
    a.booking_id,
    a.patient_name,
    a.appointment_date,
    a.appointment_time,
    a.status,
    a.no_show_checked,
    mp.name as practitioner_name
FROM appointments a
JOIN medical_practitioners mp ON a.practitioner_id = mp.id
WHERE a.status = 'CONFIRMED'
AND a.appointment_date >= CURRENT_DATE
ORDER BY a.appointment_date ASC, a.appointment_time ASC;

-- View: Payment summary
CREATE OR REPLACE VIEW payment_summary AS
SELECT 
    DATE(pt.created_at) as transaction_date,
    pt.transaction_type,
    COUNT(*) as transaction_count,
    SUM(pt.amount) as total_amount,
    SUM(pt.platform_fee) as total_platform_fees,
    SUM(pt.practitioner_amount) as total_practitioner_amount
FROM payment_transactions pt
WHERE pt.status = 'success'
GROUP BY DATE(pt.created_at), pt.transaction_type
ORDER BY transaction_date DESC;

-- =====================================================
-- 7. SAMPLE DATA FOR TESTING (Optional)
-- =====================================================

-- You can insert test practitioners and test the flow
-- Example:
-- INSERT INTO medical_practitioners (name, profession, email_address, phone_number, consultation_fee, currency)
-- VALUES ('Dr. Test Practitioner', 'General Practitioner', 'test@example.com', '+27123456789', 400, 'ZAR');

-- =====================================================
-- SETUP COMPLETE!
-- =====================================================
-- Next steps:
-- 1. Run this SQL in your Supabase SQL Editor
-- 2. Configure Paystack API keys in your frontend
-- 3. Implement webhook endpoint for Paystack callbacks
-- 4. Set up Edge Functions for automated tasks (confirmation checks, no-show handling)
-- 5. Test the complete payment flow in sandbox mode

