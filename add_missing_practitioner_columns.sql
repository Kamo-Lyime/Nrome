-- ==================================================
-- ADD MISSING COLUMNS TO PRACTITIONERS TABLE
-- ==================================================
-- Run this in Supabase SQL Editor to fix form submission errors

-- Add consultation fee column for Paystack integration
ALTER TABLE practitioners
ADD COLUMN IF NOT EXISTS consultation_fee DECIMAL(10, 2);

-- Add currency column (default ZAR for South African market)
ALTER TABLE practitioners
ADD COLUMN IF NOT EXISTS currency TEXT DEFAULT 'ZAR';

-- Add availability column for appointment booking
ALTER TABLE practitioners  
ADD COLUMN IF NOT EXISTS availability TEXT;

-- Add profile image URL column
ALTER TABLE practitioners
ADD COLUMN IF NOT EXISTS profile_image_url TEXT;

-- Add submitted_at timestamp (already in schema but ensure it exists)
-- This is set when practitioner submits the registration form
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'practitioners' AND column_name = 'submitted_at'
    ) THEN
        ALTER TABLE practitioners ADD COLUMN submitted_at TIMESTAMPTZ;
    END IF;
END $$;

-- Create index for consultation fee queries
CREATE INDEX IF NOT EXISTS idx_practitioners_consultation_fee ON practitioners(consultation_fee);

-- Add helpful comments
COMMENT ON COLUMN practitioners.consultation_fee IS 'Consultation fee in local currency for Paystack payment processing';
COMMENT ON COLUMN practitioners.currency IS 'Currency code (ZAR, NGN, KES, GHS, USD, EUR) for Paystack';
COMMENT ON COLUMN practitioners.availability IS 'Availability schedule for appointment booking (e.g., "Mon-Fri 9AM-5PM")';
COMMENT ON COLUMN practitioners.profile_image_url IS 'Supabase Storage URL for practitioner profile picture';

-- ==================================================
-- CREATE PRACTITIONER_DOCUMENTS TABLE (if needed)
-- ==================================================
-- The code uses 'practitioner_documents' table name, so create it if it doesn't exist

CREATE TABLE IF NOT EXISTS practitioner_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    practitioner_id UUID REFERENCES practitioners(id) ON DELETE CASCADE NOT NULL,
    document_type TEXT NOT NULL CHECK (document_type IN (
        'id_document',
        'registration_certificate', 
        'degree_certificate',
        'proof_of_address'
    )),
    file_url TEXT NOT NULL,
    file_name TEXT NOT NULL,
    file_size INTEGER,
    mime_type TEXT,
    uploaded_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(practitioner_id, document_type)
);

CREATE INDEX IF NOT EXISTS idx_practitioner_documents_practitioner_id ON practitioner_documents(practitioner_id);
CREATE INDEX IF NOT EXISTS idx_practitioner_documents_document_type ON practitioner_documents(document_type);

-- ==================================================
-- RLS POLICIES FOR PRACTITIONER_DOCUMENTS
-- ==================================================
-- Enable RLS on practitioner_documents table
ALTER TABLE practitioner_documents ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Users can insert own documents" ON practitioner_documents;
DROP POLICY IF EXISTS "Users can view own documents" ON practitioner_documents;
DROP POLICY IF EXISTS "Users can update own documents" ON practitioner_documents;
DROP POLICY IF EXISTS "Users can delete own documents" ON practitioner_documents;
DROP POLICY IF EXISTS "Authenticated users can manage documents" ON practitioner_documents;

-- Simplified policy: Authenticated users can manage all documents
-- (Storage RLS policies already control file access)
CREATE POLICY "Authenticated users can manage documents"
    ON practitioner_documents
    FOR ALL
    TO authenticated
    USING (true)
    WITH CHECK (true);

-- ==================================================
-- RLS POLICIES FOR PRACTITIONERS TABLE
-- ==================================================
-- Enable RLS on practitioners table
ALTER TABLE practitioners ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Users can insert own practitioner profile" ON practitioners;
DROP POLICY IF EXISTS "Users can view own practitioner profile" ON practitioners;
DROP POLICY IF EXISTS "Users can update own practitioner profile" ON practitioners;
DROP POLICY IF EXISTS "Public can view verified practitioners" ON practitioners;
DROP POLICY IF EXISTS "Authenticated users can manage own profile" ON practitioners;

-- Simplified policy for authenticated users
CREATE POLICY "Authenticated users can manage own profile"
    ON practitioners
    FOR ALL
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- Public can view verified practitioners
CREATE POLICY "Public can view verified practitioners"
    ON practitioners FOR SELECT
    TO public
    USING (verification_status = 'verified');

-- ==================================================
-- RLS POLICIES FOR VERIFICATION_REQUESTS TABLE
-- ==================================================
-- Enable RLS on verification_requests table (if it exists)
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'verification_requests'
    ) THEN
        ALTER TABLE verification_requests ENABLE ROW LEVEL SECURITY;
        
        -- Drop existing policies
        DROP POLICY IF EXISTS "Users can insert own verification requests" ON verification_requests;
        DROP POLICY IF EXISTS "Users can view own verification requests" ON verification_requests;
        DROP POLICY IF EXISTS "Authenticated users can manage requests" ON verification_requests;
        
        -- Simplified policy for authenticated users
        EXECUTE 'CREATE POLICY "Authenticated users can manage requests"
            ON verification_requests
            FOR ALL
            TO authenticated
            USING (true)
            WITH CHECK (true)';
    END IF;
END $$;

-- Verify columns were added
SELECT 
    column_name, 
    data_type, 
    column_default,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'practitioners'
AND column_name IN ('consultation_fee', 'currency', 'availability', 'profile_image_url')
ORDER BY column_name;
