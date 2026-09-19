-- =====================================================
-- ADD PAYMENT COLUMNS TO APPOINTMENTS TABLE
-- =====================================================
-- This adds all missing columns for the two-payment-method system:
-- 1. Medical Aid: Patient pays R0, practitioner pays R10 to accept
-- 2. Standard: Patient pays upfront, 95/5 split
-- =====================================================

-- Add is_medical_aid column (BOOLEAN)
ALTER TABLE appointments 
ADD COLUMN IF NOT EXISTS is_medical_aid BOOLEAN DEFAULT false;

-- Add medical_aid_note column (TEXT)
ALTER TABLE appointments 
ADD COLUMN IF NOT EXISTS medical_aid_note TEXT;

-- Add consultation_fee column (DECIMAL)
ALTER TABLE appointments 
ADD COLUMN IF NOT EXISTS consultation_fee DECIMAL(10,2);

-- Add paystack_fee column (DECIMAL)
ALTER TABLE appointments 
ADD COLUMN IF NOT EXISTS paystack_fee DECIMAL(10,2);

-- Add total_amount column (DECIMAL)
ALTER TABLE appointments 
ADD COLUMN IF NOT EXISTS total_amount DECIMAL(10,2);

-- Add currency column (VARCHAR)
ALTER TABLE appointments 
ADD COLUMN IF NOT EXISTS currency VARCHAR(3) DEFAULT 'ZAR';

-- Add payment_required column (BOOLEAN)
ALTER TABLE appointments 
ADD COLUMN IF NOT EXISTS payment_required BOOLEAN DEFAULT true;

-- Add medical_aid_fee_required column (BOOLEAN)
ALTER TABLE appointments 
ADD COLUMN IF NOT EXISTS medical_aid_fee_required BOOLEAN DEFAULT false;

-- Add payment_status column (VARCHAR)
-- Valid values: 'pending', 'success', 'failed', 'refunded'
ALTER TABLE appointments 
ADD COLUMN IF NOT EXISTS payment_status VARCHAR(20) DEFAULT 'pending';

-- Add amount_paid column (DECIMAL)
ALTER TABLE appointments 
ADD COLUMN IF NOT EXISTS amount_paid DECIMAL(10,2);

-- Add payment_reference column (VARCHAR) for Paystack reference
ALTER TABLE appointments 
ADD COLUMN IF NOT EXISTS payment_reference VARCHAR(100);

-- Add practitioner_amount column (DECIMAL) - 95% of consultation fee
ALTER TABLE appointments 
ADD COLUMN IF NOT EXISTS practitioner_amount DECIMAL(10,2);

-- Add platform_amount column (DECIMAL) - 5% of consultation fee
ALTER TABLE appointments 
ADD COLUMN IF NOT EXISTS platform_amount DECIMAL(10,2);

-- Add refund_status column (VARCHAR)
ALTER TABLE appointments 
ADD COLUMN IF NOT EXISTS refund_status VARCHAR(20);

-- Add refund_amount column (DECIMAL)
ALTER TABLE appointments 
ADD COLUMN IF NOT EXISTS refund_amount DECIMAL(10,2);

-- Add refund_date column (TIMESTAMP)
ALTER TABLE appointments 
ADD COLUMN IF NOT EXISTS refund_date TIMESTAMP WITH TIME ZONE;

-- Add medical_aid_fee_paid column (BOOLEAN) - Has practitioner paid R10?
ALTER TABLE appointments 
ADD COLUMN IF NOT EXISTS medical_aid_fee_paid BOOLEAN DEFAULT false;

-- Add medical_aid_fee_payment_date column (TIMESTAMP)
ALTER TABLE appointments 
ADD COLUMN IF NOT EXISTS medical_aid_fee_payment_date TIMESTAMP WITH TIME ZONE;

-- Add medical_aid_provider column (VARCHAR) - e.g., Discovery, Bonitas
ALTER TABLE appointments 
ADD COLUMN IF NOT EXISTS medical_aid_provider VARCHAR(100);

-- Add medical_aid_number column (VARCHAR)
ALTER TABLE appointments 
ADD COLUMN IF NOT EXISTS medical_aid_number VARCHAR(100);

-- =====================================================
-- Create indexes for performance
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_appointments_is_medical_aid 
ON appointments(is_medical_aid);

CREATE INDEX IF NOT EXISTS idx_appointments_payment_status 
ON appointments(payment_status);

CREATE INDEX IF NOT EXISTS idx_appointments_payment_reference 
ON appointments(payment_reference);

-- =====================================================
-- Add comments to columns for documentation
-- =====================================================

COMMENT ON COLUMN appointments.is_medical_aid IS 'TRUE if patient using medical aid (R0 patient, R10 practitioner), FALSE if standard payment (patient pays upfront, 95/5 split)';
COMMENT ON COLUMN appointments.medical_aid_note IS 'Notes about medical aid billing process';
COMMENT ON COLUMN appointments.consultation_fee IS 'Base consultation fee (e.g., R500)';
COMMENT ON COLUMN appointments.paystack_fee IS 'Paystack processing fee (e.g., R9 for R500 transaction)';
COMMENT ON COLUMN appointments.total_amount IS 'Total amount charged to patient (consultation_fee + paystack_fee for standard, R0 for medical aid)';
COMMENT ON COLUMN appointments.payment_status IS 'Status of payment: pending, success, failed, refunded';
COMMENT ON COLUMN appointments.medical_aid_fee_paid IS 'Has practitioner paid R10 fee to accept medical aid booking?';
COMMENT ON COLUMN appointments.practitioner_amount IS '95% of consultation fee (what practitioner receives for standard bookings)';
COMMENT ON COLUMN appointments.platform_amount IS '5% of consultation fee (platform revenue)';

-- =====================================================
-- Verification Query
-- =====================================================
-- Run this to verify all columns were added:
/*
SELECT 
    column_name, 
    data_type, 
    column_default,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'appointments'
    AND column_name IN (
        'is_medical_aid', 
        'medical_aid_note', 
        'consultation_fee',
        'paystack_fee',
        'total_amount',
        'currency',
        'payment_required',
        'medical_aid_fee_required',
        'payment_status',
        'amount_paid',
        'payment_reference',
        'practitioner_amount',
        'platform_amount',
        'medical_aid_fee_paid'
    )
ORDER BY column_name;
*/

-- =====================================================
-- Success Message
-- =====================================================
DO $$ 
BEGIN 
    RAISE NOTICE '✅ All payment columns added to appointments table successfully!';
    RAISE NOTICE 'You can now create appointments with both payment methods:';
    RAISE NOTICE '  - Medical Aid: is_medical_aid = true, patient pays R0, practitioner pays R10';
    RAISE NOTICE '  - Standard: is_medical_aid = false, patient pays upfront, 95/5 split';
END $$;
