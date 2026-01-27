-- =====================================================
-- QUICK FIX: Drop old tables and recreate with correct schema
-- =====================================================
-- Run this in Supabase SQL Editor to fix the schema mismatch

-- Step 1: Drop old tables
DROP TABLE IF EXISTS medication_orders CASCADE;
DROP TABLE IF EXISTS prescriptions CASCADE;

-- Step 2: Now run the full supabase_setup.sql file
-- Or continue below with the full schema:

-- =====================================================
-- PRESCRIPTIONS TABLE (with snake_case columns)
-- =====================================================
CREATE TABLE prescriptions (
    id TEXT PRIMARY KEY,
    file_name TEXT NOT NULL,
    file_data TEXT NOT NULL,
    doctor_name TEXT NOT NULL,
    prescription_date DATE NOT NULL,
    prescription_expiry DATE,
    refills_allowed INTEGER DEFAULT 0 CHECK (refills_allowed >= 0 AND refills_allowed <= 12),
    notes TEXT,
    upload_date TIMESTAMPTZ DEFAULT NOW(),
    status TEXT DEFAULT 'Pending Verification' CHECK (status IN ('Pending Verification', 'Verified', 'Rejected', 'Expired')),
    verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_prescriptions_status ON prescriptions(status);
CREATE INDEX idx_prescriptions_upload_date ON prescriptions(upload_date DESC);
CREATE INDEX idx_prescriptions_doctor ON prescriptions(doctor_name);

-- =====================================================
-- MEDICATION ORDERS TABLE (with snake_case columns)
-- =====================================================
CREATE TABLE medication_orders (
    order_id TEXT PRIMARY KEY,
    patient_name TEXT NOT NULL,
    patient_age INTEGER CHECK (patient_age > 0 AND patient_age <= 120),
    allergies TEXT NOT NULL,
    current_medications TEXT,
    medical_conditions TEXT,
    medications JSONB NOT NULL,
    delivery_date DATE NOT NULL,
    delivery_time TEXT CHECK (delivery_time IN ('morning', 'afternoon', 'evening', 'anytime')),
    delivery_address TEXT NOT NULL,
    phone_number TEXT NOT NULL,
    emergency_contact TEXT NOT NULL,
    email TEXT NOT NULL,
    insurance_provider TEXT,
    insurance_number TEXT,
    payment_method TEXT NOT NULL CHECK (payment_method IN ('mpesa', 'insurance', 'cash', 'card')),
    additional_comments TEXT,
    prescription_id TEXT REFERENCES prescriptions(id) ON DELETE SET NULL,
    order_date TIMESTAMPTZ DEFAULT NOW(),
    status TEXT DEFAULT 'Pending Verification' CHECK (status IN ('Pending Verification', 'Verified', 'Processing', 'Out for Delivery', 'Delivered', 'Cancelled')),
    verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_orders_status ON medication_orders(status);
CREATE INDEX idx_orders_date ON medication_orders(order_date DESC);
CREATE INDEX idx_orders_patient ON medication_orders(patient_name);
CREATE INDEX idx_orders_prescription ON medication_orders(prescription_id);
CREATE INDEX idx_orders_delivery_date ON medication_orders(delivery_date);

-- =====================================================
-- RLS POLICIES
-- =====================================================
ALTER TABLE prescriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE medication_orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all operations on prescriptions" 
ON prescriptions FOR ALL USING (true) WITH CHECK (true);

CREATE POLICY "Allow all operations on medication_orders" 
ON medication_orders FOR ALL USING (true) WITH CHECK (true);

-- =====================================================
-- TRIGGERS
-- =====================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_prescriptions_updated_at 
BEFORE UPDATE ON prescriptions 
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_medication_orders_updated_at 
BEFORE UPDATE ON medication_orders 
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Done! Refresh your medication.html page and try again
