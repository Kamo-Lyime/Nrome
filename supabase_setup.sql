
-- Enable UUID utilities
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =====================================================
-- 1. PRESCRIPTIONS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS prescriptions (
    id TEXT PRIMARY KEY,
    file_name TEXT NOT NULL,
    file_data TEXT NOT NULL, -- Base64 encoded file
    doctor_name TEXT NOT NULL,
    prescription_date DATE NOT NULL,
    prescription_expiry DATE,
    refills_allowed INTEGER DEFAULT 0 CHECK (refills_allowed >= 0 AND refills_allowed <= 12),
    notes TEXT,
    upload_date TIMESTAMPTZ DEFAULT NOW(),
    status TEXT DEFAULT 'Pending Verification' CHECK (status IN ('Pending Verification', 'Verified', 'Rejected', 'Expired')),
    verified BOOLEAN DEFAULT FALSE,
    user_id UUID REFERENCES auth.users(id), -- Patient's user ID
    practitioner_id UUID REFERENCES medical_practitioners(id), -- Practitioner who uploaded
    uploaded_by_user_id UUID REFERENCES auth.users(id), -- Practitioner's user account
    patient_name TEXT, -- Patient name for easy reference
    patient_email TEXT, -- Patient email for searching
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Ensure user linkage exists when table was created earlier without it
ALTER TABLE prescriptions
    ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);

ALTER TABLE prescriptions
    ADD COLUMN IF NOT EXISTS practitioner_id UUID REFERENCES medical_practitioners(id);

ALTER TABLE prescriptions
    ADD COLUMN IF NOT EXISTS uploaded_by_user_id UUID REFERENCES auth.users(id);

ALTER TABLE prescriptions
    ADD COLUMN IF NOT EXISTS patient_name TEXT;

ALTER TABLE prescriptions
    ADD COLUMN IF NOT EXISTS patient_email TEXT;

-- Index for faster queries
CREATE INDEX IF NOT EXISTS idx_prescriptions_status ON prescriptions(status);
CREATE INDEX IF NOT EXISTS idx_prescriptions_upload_date ON prescriptions(upload_date DESC);
CREATE INDEX IF NOT EXISTS idx_prescriptions_doctor ON prescriptions(doctor_name);
CREATE INDEX IF NOT EXISTS idx_prescriptions_practitioner ON prescriptions(practitioner_id);
CREATE INDEX IF NOT EXISTS idx_prescriptions_patient_email ON prescriptions(patient_email);

-- =====================================================
-- 2. MEDICATION ORDERS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS medication_orders (
    order_id TEXT PRIMARY KEY,
    
    -- Patient Information
    patient_name TEXT NOT NULL,
    patient_age INTEGER CHECK (patient_age > 0 AND patient_age <= 120),
    allergies TEXT NOT NULL,
    current_medications TEXT,
    medical_conditions TEXT,
    
    -- Medication Details (stored as JSONB for flexibility)
    medications JSONB NOT NULL,
    
    -- Delivery Information
    delivery_date DATE NOT NULL,
    delivery_time TEXT CHECK (delivery_time IN ('morning', 'afternoon', 'evening', 'anytime')),
    delivery_address TEXT NOT NULL,
    
    -- Contact Information
    phone_number TEXT NOT NULL,
    emergency_contact TEXT NOT NULL,
    email TEXT NOT NULL,
    
    -- Payment & Insurance
    insurance_provider TEXT,
    insurance_number TEXT,
    payment_method TEXT NOT NULL CHECK (payment_method IN ('mpesa', 'insurance', 'cash', 'card')),
    
    -- Additional Information
    additional_comments TEXT,
    prescription_id TEXT REFERENCES prescriptions(id) ON DELETE SET NULL,
    
    -- Order Metadata
    order_date TIMESTAMPTZ DEFAULT NOW(),
    status TEXT DEFAULT 'Pending Verification' CHECK (status IN ('Pending Verification', 'Verified', 'Processing', 'Out for Delivery', 'Delivered', 'Cancelled')),
    verified BOOLEAN DEFAULT FALSE,
    user_id UUID REFERENCES auth.users(id),
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Ensure user linkage exists when table was created earlier without it
ALTER TABLE medication_orders
    ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);

-- Indexes for faster queries (using exact column names from table)
CREATE INDEX IF NOT EXISTS idx_orders_status ON medication_orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_date ON medication_orders(order_date DESC);
CREATE INDEX IF NOT EXISTS idx_orders_patient ON medication_orders(patient_name);
CREATE INDEX IF NOT EXISTS idx_orders_prescription ON medication_orders(prescription_id);
CREATE INDEX IF NOT EXISTS idx_orders_delivery_date ON medication_orders(delivery_date);

-- =====================================================
-- 3. ENABLE ROW LEVEL SECURITY (RLS)
-- =====================================================
ALTER TABLE prescriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE medication_orders ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- 4. RLS POLICIES (Allow all operations for now - customize based on your auth)
-- =====================================================

-- Drop overly permissive prescription policy
DROP POLICY IF EXISTS "Allow all operations on prescriptions" ON prescriptions;

-- Patients can view prescriptions uploaded for them
CREATE POLICY "Allow patients to view their prescriptions"
ON prescriptions
FOR SELECT
USING (auth.uid() = user_id);

-- Practitioners can view prescriptions they uploaded
CREATE POLICY "Allow practitioners to view their prescriptions"
ON prescriptions
FOR SELECT
USING (
    practitioner_id IN (
        SELECT id FROM medical_practitioners WHERE owner_user_id = auth.uid()
    )
);

-- Practitioners can upload prescriptions for their patients
CREATE POLICY "Allow practitioners to upload prescriptions"
ON prescriptions
FOR INSERT
WITH CHECK (
    uploaded_by_user_id = auth.uid() AND
    practitioner_id IN (
        SELECT id FROM medical_practitioners WHERE owner_user_id = auth.uid()
    )
);

-- Medication Orders: Allow all operations (customize based on your authentication)
CREATE POLICY "Allow all operations on medication_orders" 
ON medication_orders 
FOR ALL 
USING (true) 
WITH CHECK (true);

-- =====================================================
-- 5. UPDATED_AT TRIGGER FUNCTIONS
-- =====================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers to auto-update updated_at
CREATE TRIGGER update_prescriptions_updated_at 
BEFORE UPDATE ON prescriptions 
FOR EACH ROW 
EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_medication_orders_updated_at 
BEFORE UPDATE ON medication_orders 
FOR EACH ROW 
EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- 7. MEDICAL PRACTITIONERS TABLE (for listings/profiles)
-- =====================================================
CREATE TABLE IF NOT EXISTS medical_practitioners (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID REFERENCES auth.users(id),
    name TEXT NOT NULL,
    profession TEXT NOT NULL,
    qualifications TEXT,
    license_number TEXT,
    experience_years INTEGER DEFAULT 0,
    service_description TEXT,
    consultation_fee NUMERIC,
    currency TEXT,
    serving_locations TEXT,
    availability TEXT,
    phone_number TEXT,
    email_address TEXT,
    profile_image_url TEXT,
    verified BOOLEAN DEFAULT FALSE,
    rating NUMERIC DEFAULT 0,
    total_patients INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Ensure owner linkage exists when table was created earlier without it (do this before indexes)
ALTER TABLE medical_practitioners
    ADD COLUMN IF NOT EXISTS owner_user_id UUID REFERENCES auth.users(id);

CREATE INDEX IF NOT EXISTS idx_practitioners_owner ON medical_practitioners(owner_user_id);
CREATE INDEX IF NOT EXISTS idx_practitioners_profession ON medical_practitioners(profession);

-- =====================================================
-- 8. AI USAGE LOGS (per-user history of AI interactions)
-- =====================================================
CREATE TABLE IF NOT EXISTS ai_usage_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id),
    feature TEXT,
    input_text TEXT,
    output_text TEXT,
    payload JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE ai_usage_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all operations on ai_usage_logs" ON ai_usage_logs;
CREATE POLICY "Allow all operations on ai_usage_logs"
ON ai_usage_logs
FOR ALL
USING (true)
WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_ai_usage_user_id ON ai_usage_logs(user_id);

-- =====================================================
-- 8. APPOINTMENTS TABLE (patient bookings)
-- =====================================================
CREATE TABLE IF NOT EXISTS appointments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id TEXT UNIQUE NOT NULL,
    user_id UUID REFERENCES auth.users(id),
    practitioner_id UUID REFERENCES medical_practitioners(id) ON DELETE SET NULL,
    practitioner_name TEXT NOT NULL,
    patient_name TEXT NOT NULL,
    patient_phone TEXT NOT NULL,
    patient_email TEXT,
    appointment_date DATE NOT NULL,
    appointment_time TEXT NOT NULL,
    appointment_type TEXT DEFAULT 'consultation',
    reason_for_visit TEXT,
    status TEXT DEFAULT 'pending',
    rescheduled_date DATE,
    rescheduled_time TEXT,
    cancellation_reason TEXT,
    practitioner_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Ensure auth/user linkage exists when table was created earlier without it
ALTER TABLE appointments
    ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);

-- Ensure updated_at column exists (may be missing in older versions)
ALTER TABLE appointments
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_appointments_user ON appointments(user_id);
CREATE INDEX IF NOT EXISTS idx_appointments_date ON appointments(appointment_date DESC);
CREATE INDEX IF NOT EXISTS idx_appointments_practitioner ON appointments(practitioner_id);

-- =====================================================
-- 9. PRACTITIONER NOTIFICATIONS (in-app tracking)
-- =====================================================
CREATE TABLE IF NOT EXISTS practitioner_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    practitioner_id UUID REFERENCES medical_practitioners(id) ON DELETE CASCADE,
    appointment_id TEXT,
    notification_type TEXT,
    message TEXT,
    sent_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_practitioner ON practitioner_notifications(practitioner_id);

-- Enable RLS for new tables
ALTER TABLE medical_practitioners ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE practitioner_notifications ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to avoid duplicate-name errors (Postgres lacks IF NOT EXISTS for policies)
DROP POLICY IF EXISTS "Allow all operations on practitioners" ON medical_practitioners;
DROP POLICY IF EXISTS "Allow all operations on appointments" ON appointments;
DROP POLICY IF EXISTS "Allow patients to view their appointments" ON appointments;
DROP POLICY IF EXISTS "Allow practitioners to view their appointments" ON appointments;
DROP POLICY IF EXISTS "Allow patients to create appointments" ON appointments;
DROP POLICY IF EXISTS "Allow practitioners to update appointments" ON appointments;
DROP POLICY IF EXISTS "Allow all operations on practitioner_notifications" ON practitioner_notifications;

CREATE POLICY "Allow all operations on practitioners" 
ON medical_practitioners 
FOR ALL 
USING (true) 
WITH CHECK (true);

-- Separate policies for appointments to enable proper patient-practitioner linking

-- Patients can view their own appointments
CREATE POLICY "Allow patients to view their appointments" 
ON appointments 
FOR SELECT 
USING (auth.uid() = user_id);

-- Practitioners can view appointments booked with them
CREATE POLICY "Allow practitioners to view their appointments" 
ON appointments 
FOR SELECT 
USING (
    practitioner_id IN (
        SELECT id FROM medical_practitioners WHERE owner_user_id = auth.uid()
    )
);

-- Anyone authenticated can create appointments
CREATE POLICY "Allow patients to create appointments" 
ON appointments 
FOR INSERT 
WITH CHECK (auth.uid() = user_id);

-- Practitioners can update appointments booked with them (status changes, etc.)
CREATE POLICY "Allow practitioners to update appointments" 
ON appointments 
FOR UPDATE 
USING (
    practitioner_id IN (
        SELECT id FROM medical_practitioners WHERE owner_user_id = auth.uid()
    )
);

CREATE POLICY "Allow all operations on practitioner_notifications" 
ON practitioner_notifications 
FOR ALL 
USING (true) 
WITH CHECK (true);

-- =====================================================
-- 6. VERIFICATION VIEWS (Optional - for admins)
-- =====================================================
CREATE OR REPLACE VIEW pending_prescriptions AS
SELECT id, doctor_name, prescription_date, upload_date, file_name
FROM prescriptions
WHERE verified = FALSE
ORDER BY upload_date DESC;

CREATE OR REPLACE VIEW pending_orders AS
SELECT order_id, patient_name, order_date, delivery_date, status, prescription_id
FROM medication_orders
WHERE verified = FALSE
ORDER BY order_date DESC;

-- =====================================================
-- SETUP COMPLETE! 
-- =====================================================
-- Your tables are now ready to use with the medication.html system
-- 
-- Next Steps:
-- 1. Make sure your Supabase URL and ANON_KEY are correct in medication.html
-- 2. Test prescription uploads
-- 3. Test medication orders
-- 4. Customize RLS policies based on your authentication needs
-- 5. Consider adding user authentication to track which user uploaded which prescription
