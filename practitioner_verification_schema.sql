-- ==================================================
-- PRACTITIONER VERIFICATION SYSTEM - COMPLETE SCHEMA
-- ==================================================
-- This schema implements a comprehensive practitioner verification system
-- for medical professionals including doctors, nurses, and other healthcare practitioners

-- ==================================================
-- PHASE 1: DATABASE DESIGN
-- ==================================================

-- Drop existing tables if they exist (in reverse order of dependencies)
DROP TABLE IF EXISTS verification_audit CASCADE;
DROP TABLE IF EXISTS ai_document_extractions CASCADE;
DROP TABLE IF EXISTS trust_scores CASCADE;
DROP TABLE IF EXISTS verification_requests CASCADE;
DROP TABLE IF EXISTS documents CASCADE;
DROP TABLE IF EXISTS practitioners CASCADE;

-- ==================================================
-- PRACTITIONERS TABLE
-- ==================================================
-- Stores core practitioner profile information
CREATE TABLE practitioners (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    full_name TEXT NOT NULL,
    profession TEXT NOT NULL, -- e.g., "Medical Practitioner", "Nurse", "Specialist"
    registration_number TEXT NOT NULL, -- HPCSA or SANC number
    practice_number TEXT, -- Board of Healthcare Funders (BHF) practice number
    specialty TEXT, -- e.g., "General Practice", "Cardiology", "Critical Care Nursing"
    practice_name TEXT,
    address TEXT NOT NULL, -- Hidden from patients, used for AI location recommendations
    latitude DECIMAL(10, 8), -- For geolocation matching
    longitude DECIMAL(11, 8), -- For geolocation matching
    medical_scheme_billing_supported BOOLEAN DEFAULT false,
    
    -- Verification status tracking
    verification_status TEXT DEFAULT 'draft' CHECK (verification_status IN (
        'draft', 
        'pending_documents',
        'pending_review', 
        'under_review', 
        'verified', 
        'rejected', 
        'expired'
    )),
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    submitted_at TIMESTAMPTZ, -- When practitioner submitted for review
    verified_at TIMESTAMPTZ, -- When admin verified
    last_verified_at TIMESTAMPTZ, -- Last reverification date
    verification_expires_at TIMESTAMPTZ, -- Expiry date (12 months after verification)
    
    -- Trust scoring
    trust_score INTEGER DEFAULT 0 CHECK (trust_score >= 0 AND trust_score <= 100),
    
    -- Internal notes
    internal_notes TEXT,
    
    -- Ensure unique registration numbers per profession type
    UNIQUE(registration_number, profession)
);

-- Create indexes for performance
CREATE INDEX idx_practitioners_user_id ON practitioners(user_id);
CREATE INDEX idx_practitioners_verification_status ON practitioners(verification_status);
CREATE INDEX idx_practitioners_registration_number ON practitioners(registration_number);
CREATE INDEX idx_practitioners_location ON practitioners(latitude, longitude);
CREATE INDEX idx_practitioners_verified_at ON practitioners(verified_at);
CREATE INDEX idx_practitioners_verification_expires_at ON practitioners(verification_expires_at);

-- ==================================================
-- DOCUMENTS TABLE
-- ==================================================
-- Stores uploaded verification documents
CREATE TABLE documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    practitioner_id UUID REFERENCES practitioners(id) ON DELETE CASCADE NOT NULL,
    document_type TEXT NOT NULL CHECK (document_type IN (
        'id_document',
        'registration_certificate', 
        'degree_certificate',
        'proof_of_address'
    )),
    file_url TEXT NOT NULL, -- Supabase Storage URL
    file_name TEXT NOT NULL,
    file_size INTEGER, -- File size in bytes
    mime_type TEXT,
    
    -- AI extraction tracking
    ai_extracted BOOLEAN DEFAULT false,
    ai_extraction_attempted_at TIMESTAMPTZ,
    
    uploaded_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Ensure one document per type per practitioner
    UNIQUE(practitioner_id, document_type)
);

CREATE INDEX idx_documents_practitioner_id ON documents(practitioner_id);
CREATE INDEX idx_documents_document_type ON documents(document_type);
CREATE INDEX idx_documents_ai_extracted ON documents(ai_extracted);

-- ==================================================
-- VERIFICATION REQUESTS TABLE
-- ==================================================
-- Tracks verification workflow and admin reviews
CREATE TABLE verification_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    practitioner_id UUID REFERENCES practitioners(id) ON DELETE CASCADE NOT NULL,
    status TEXT DEFAULT 'pending_review' CHECK (status IN (
        'pending_review',
        'under_review',
        'approved',
        'rejected',
        'more_info_required'
    )),
    
    -- Submission tracking
    submitted_at TIMESTAMPTZ DEFAULT NOW(),
    reviewed_at TIMESTAMPTZ,
    reviewed_by UUID REFERENCES auth.users(id), -- Admin user who reviewed
    
    -- Review details
    review_notes TEXT,
    rejection_reason TEXT,
    additional_info_requested TEXT,
    
    -- AI assistance data
    ai_confidence_score INTEGER, -- 0-100
    ai_discrepancies JSONB, -- Array of detected issues
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_verification_requests_practitioner_id ON verification_requests(practitioner_id);
CREATE INDEX idx_verification_requests_status ON verification_requests(status);
CREATE INDEX idx_verification_requests_submitted_at ON verification_requests(submitted_at);
CREATE INDEX idx_verification_requests_reviewed_by ON verification_requests(reviewed_by);

-- ==================================================
-- VERIFICATION AUDIT TABLE
-- ==================================================
-- Complete audit trail of all verification actions
CREATE TABLE verification_audit (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    practitioner_id UUID REFERENCES practitioners(id) ON DELETE CASCADE NOT NULL,
    action TEXT NOT NULL, -- e.g., 'status_changed', 'document_uploaded', 'approved', 'rejected'
    previous_status TEXT,
    new_status TEXT,
    notes TEXT,
    admin_id UUID REFERENCES auth.users(id), -- Admin who performed action (null if system action)
    metadata JSONB, -- Additional context data
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_verification_audit_practitioner_id ON verification_audit(practitioner_id);
CREATE INDEX idx_verification_audit_admin_id ON verification_audit(admin_id);
CREATE INDEX idx_verification_audit_created_at ON verification_audit(created_at);
CREATE INDEX idx_verification_audit_action ON verification_audit(action);

-- ==================================================
-- AI DOCUMENT EXTRACTIONS TABLE
-- ==================================================
-- Stores AI-extracted data from documents for verification
CREATE TABLE ai_document_extractions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID REFERENCES documents(id) ON DELETE CASCADE NOT NULL,
    practitioner_id UUID REFERENCES practitioners(id) ON DELETE CASCADE NOT NULL,
    
    -- Extracted fields
    extracted_full_name TEXT,
    extracted_registration_number TEXT,
    extracted_profession TEXT,
    extracted_institution TEXT,
    extracted_qualification TEXT,
    extracted_issue_date DATE,
    extracted_expiry_date DATE,
    
    -- AI metadata
    extraction_confidence DECIMAL(5, 2), -- 0.00 to 100.00
    raw_extraction JSONB, -- Full AI response
    model_used TEXT, -- e.g., "grok-2-vision"
    
    -- Verification matching
    name_match_score INTEGER, -- 0-100
    registration_match_score INTEGER, -- 0-100
    overall_match_score INTEGER, -- 0-100
    discrepancies JSONB, -- List of detected issues
    
    extracted_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(document_id)
);

CREATE INDEX idx_ai_extractions_document_id ON ai_document_extractions(document_id);
CREATE INDEX idx_ai_extractions_practitioner_id ON ai_document_extractions(practitioner_id);
CREATE INDEX idx_ai_extractions_overall_match_score ON ai_document_extractions(overall_match_score);

-- ==================================================
-- TRUST SCORES TABLE
-- ==================================================
-- Detailed breakdown of practitioner trust scoring
CREATE TABLE trust_scores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    practitioner_id UUID REFERENCES practitioners(id) ON DELETE CASCADE NOT NULL,
    
    -- Score components (out of 100 total)
    name_verified_score INTEGER DEFAULT 0, -- 10 points
    documents_complete_score INTEGER DEFAULT 0, -- 10 points
    id_verified_score INTEGER DEFAULT 0, -- 20 points
    registration_verified_score INTEGER DEFAULT 0, -- 40 points
    practice_number_verified_score INTEGER DEFAULT 0, -- 20 points
    
    -- Total
    total_score INTEGER DEFAULT 0 CHECK (total_score >= 0 AND total_score <= 100),
    
    -- Metadata
    calculation_details JSONB,
    calculated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(practitioner_id)
);

CREATE INDEX idx_trust_scores_practitioner_id ON trust_scores(practitioner_id);
CREATE INDEX idx_trust_scores_total_score ON trust_scores(total_score);

-- ==================================================
-- ADMIN USERS VIEW
-- ==================================================
-- Create a view for easy admin user identification
CREATE OR REPLACE VIEW admin_users AS
SELECT 
    u.id,
    u.email,
    up.full_name,
    up.phone,
    ura.role,
    ura.assigned_at
FROM auth.users u
JOIN user_profiles up ON u.id = up.id
JOIN user_role_assignments ura ON u.id = ura.user_id
WHERE ura.role = 'admin';

-- ==================================================
-- FUNCTIONS & TRIGGERS
-- ==================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for practitioners table
CREATE TRIGGER update_practitioners_updated_at
    BEFORE UPDATE ON practitioners
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Trigger for verification_requests table
CREATE TRIGGER update_verification_requests_updated_at
    BEFORE UPDATE ON verification_requests
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Function to automatically calculate trust score
CREATE OR REPLACE FUNCTION calculate_trust_score(p_practitioner_id UUID)
RETURNS INTEGER AS $$
DECLARE
    v_practitioner practitioners;
    v_documents_count INTEGER;
    v_ai_extractions_verified INTEGER;
    v_score INTEGER := 0;
BEGIN
    -- Get practitioner details
    SELECT * INTO v_practitioner FROM practitioners WHERE id = p_practitioner_id;
    
    -- Name verified (10 points)
    IF v_practitioner.full_name IS NOT NULL AND LENGTH(v_practitioner.full_name) > 0 THEN
        v_score := v_score + 10;
    END IF;
    
    -- All documents uploaded (10 points)
    SELECT COUNT(*) INTO v_documents_count
    FROM documents
    WHERE practitioner_id = p_practitioner_id;
    
    IF v_documents_count >= 4 THEN -- All 4 required documents
        v_score := v_score + 10;
    END IF;
    
    -- ID document uploaded (20 points)
    IF EXISTS (
        SELECT 1 FROM documents 
        WHERE practitioner_id = p_practitioner_id 
        AND document_type = 'id_document'
    ) THEN
        v_score := v_score + 20;
    END IF;
    
    -- Registration certificate verified (40 points)
    IF v_practitioner.verification_status = 'verified' THEN
        v_score := v_score + 40;
    END IF;
    
    -- Practice number verified (20 points)
    IF v_practitioner.practice_number IS NOT NULL 
       AND LENGTH(v_practitioner.practice_number) > 0 
       AND v_practitioner.verification_status = 'verified' THEN
        v_score := v_score + 20;
    END IF;
    
    -- Upsert trust score
    INSERT INTO trust_scores (
        practitioner_id,
        name_verified_score,
        documents_complete_score,
        id_verified_score,
        registration_verified_score,
        practice_number_verified_score,
        total_score,
        calculated_at
    ) VALUES (
        p_practitioner_id,
        CASE WHEN v_practitioner.full_name IS NOT NULL THEN 10 ELSE 0 END,
        CASE WHEN v_documents_count >= 4 THEN 10 ELSE 0 END,
        CASE WHEN EXISTS (SELECT 1 FROM documents WHERE practitioner_id = p_practitioner_id AND document_type = 'id_document') THEN 20 ELSE 0 END,
        CASE WHEN v_practitioner.verification_status = 'verified' THEN 40 ELSE 0 END,
        CASE WHEN v_practitioner.practice_number IS NOT NULL AND v_practitioner.verification_status = 'verified' THEN 20 ELSE 0 END,
        v_score,
        NOW()
    )
    ON CONFLICT (practitioner_id) DO UPDATE SET
        name_verified_score = EXCLUDED.name_verified_score,
        documents_complete_score = EXCLUDED.documents_complete_score,
        id_verified_score = EXCLUDED.id_verified_score,
        registration_verified_score = EXCLUDED.registration_verified_score,
        practice_number_verified_score = EXCLUDED.practice_number_verified_score,
        total_score = EXCLUDED.total_score,
        calculated_at = NOW();
    
    -- Update practitioners table
    UPDATE practitioners 
    SET trust_score = v_score 
    WHERE id = p_practitioner_id;
    
    RETURN v_score;
END;
$$ LANGUAGE plpgsql;

-- Function to create audit log entry
CREATE OR REPLACE FUNCTION create_audit_log(
    p_practitioner_id UUID,
    p_action TEXT,
    p_previous_status TEXT,
    p_new_status TEXT,
    p_notes TEXT,
    p_admin_id UUID DEFAULT NULL,
    p_metadata JSONB DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_audit_id UUID;
BEGIN
    INSERT INTO verification_audit (
        practitioner_id,
        action,
        previous_status,
        new_status,
        notes,
        admin_id,
        metadata
    ) VALUES (
        p_practitioner_id,
        p_action,
        p_previous_status,
        p_new_status,
        p_notes,
        p_admin_id,
        p_metadata
    )
    RETURNING id INTO v_audit_id;
    
    RETURN v_audit_id;
END;
$$ LANGUAGE plpgsql;

-- Function to check if practitioner has expired verification
CREATE OR REPLACE FUNCTION check_expired_verifications()
RETURNS void AS $$
BEGIN
    UPDATE practitioners
    SET verification_status = 'expired'
    WHERE verification_status = 'verified'
    AND verification_expires_at < NOW();
    
    -- Create audit log for expired verifications
    INSERT INTO verification_audit (practitioner_id, action, previous_status, new_status, notes)
    SELECT 
        id,
        'verification_expired',
        'verified',
        'expired',
        'Verification expired after 12 months'
    FROM practitioners
    WHERE verification_status = 'expired'
    AND verified_at < NOW() - INTERVAL '12 months';
END;
$$ LANGUAGE plpgsql;

-- ==================================================
-- COMMENTS FOR DOCUMENTATION
-- ==================================================

COMMENT ON TABLE practitioners IS 'Core practitioner profiles for medical professionals';
COMMENT ON TABLE documents IS 'Uploaded verification documents (ID, certificates, proof of address)';
COMMENT ON TABLE verification_requests IS 'Admin review workflow for practitioner verification';
COMMENT ON TABLE verification_audit IS 'Complete audit trail of all verification actions';
COMMENT ON TABLE ai_document_extractions IS 'AI-extracted data from uploaded documents';
COMMENT ON TABLE trust_scores IS 'Detailed trust score breakdown for practitioners';

COMMENT ON COLUMN practitioners.address IS 'Hidden from patients, used by AI for location-based recommendations';
COMMENT ON COLUMN practitioners.verification_expires_at IS 'Verification expires 12 months after verification date';
COMMENT ON COLUMN practitioners.trust_score IS 'Calculated score 0-100 based on verification completeness';
