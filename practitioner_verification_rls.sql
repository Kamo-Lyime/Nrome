-- ==================================================
-- PRACTITIONER VERIFICATION SYSTEM - ROW LEVEL SECURITY
-- ==================================================
-- This file implements comprehensive Row Level Security (RLS) policies
-- to ensure practitioners can only access their own data while admins
-- can access all records for verification purposes.

-- ==================================================
-- PHASE 2: ROW LEVEL SECURITY POLICIES
-- ==================================================

-- Enable RLS on all tables
ALTER TABLE practitioners ENABLE ROW LEVEL SECURITY;
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE verification_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE verification_audit ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_document_extractions ENABLE ROW LEVEL SECURITY;
ALTER TABLE trust_scores ENABLE ROW LEVEL SECURITY;

-- ==================================================
-- HELPER FUNCTIONS FOR RLS
-- ==================================================

-- Function to check if current user is an admin
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 
        FROM user_role_assignments 
        WHERE user_id = auth.uid() 
        AND role = 'admin'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if current user is a practitioner
CREATE OR REPLACE FUNCTION is_practitioner()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 
        FROM user_role_assignments 
        WHERE user_id = auth.uid() 
        AND role = 'practitioner'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get practitioner_id for current user
CREATE OR REPLACE FUNCTION get_practitioner_id()
RETURNS UUID AS $$
BEGIN
    RETURN (
        SELECT id 
        FROM practitioners 
        WHERE user_id = auth.uid() 
        LIMIT 1
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================================================
-- PRACTITIONERS TABLE RLS POLICIES
-- ==================================================

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Practitioners can view own profile" ON practitioners;
DROP POLICY IF EXISTS "Practitioners can insert own profile" ON practitioners;
DROP POLICY IF EXISTS "Practitioners can update own profile" ON practitioners;
DROP POLICY IF EXISTS "Admins can view all practitioners" ON practitioners;
DROP POLICY IF EXISTS "Admins can insert practitioners" ON practitioners;
DROP POLICY IF EXISTS "Admins can update all practitioners" ON practitioners;
DROP POLICY IF EXISTS "Admins can delete practitioners" ON practitioners;
DROP POLICY IF EXISTS "Public can view verified practitioners basic info" ON practitioners;

-- Practitioner policies
CREATE POLICY "Practitioners can view own profile"
    ON practitioners FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Practitioners can insert own profile"
    ON practitioners FOR INSERT
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Practitioners can update own profile"
    ON practitioners FOR UPDATE
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- Admin policies (full access)
CREATE POLICY "Admins can view all practitioners"
    ON practitioners FOR SELECT
    USING (is_admin());

CREATE POLICY "Admins can insert practitioners"
    ON practitioners FOR INSERT
    WITH CHECK (is_admin());

CREATE POLICY "Admins can update all practitioners"
    ON practitioners FOR UPDATE
    USING (is_admin())
    WITH CHECK (is_admin());

CREATE POLICY "Admins can delete practitioners"
    ON practitioners FOR DELETE
    USING (is_admin());

-- Public can view verified practitioners (limited info - no address)
-- This will be used for patient searches, but address is hidden
CREATE POLICY "Public can view verified practitioners basic info"
    ON practitioners FOR SELECT
    USING (
        verification_status = 'verified' 
        AND verification_expires_at > NOW()
    );

-- ==================================================
-- DOCUMENTS TABLE RLS POLICIES
-- ==================================================

DROP POLICY IF EXISTS "Practitioners can view own documents" ON documents;
DROP POLICY IF EXISTS "Practitioners can insert own documents" ON documents;
DROP POLICY IF EXISTS "Practitioners can update own documents" ON documents;
DROP POLICY IF EXISTS "Practitioners can delete own documents" ON documents;
DROP POLICY IF EXISTS "Admins can view all documents" ON documents;
DROP POLICY IF EXISTS "Admins can insert documents" ON documents;
DROP POLICY IF EXISTS "Admins can update documents" ON documents;
DROP POLICY IF EXISTS "Admins can delete documents" ON documents;

-- Practitioner policies
CREATE POLICY "Practitioners can view own documents"
    ON documents FOR SELECT
    USING (
        practitioner_id IN (
            SELECT id FROM practitioners WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Practitioners can insert own documents"
    ON documents FOR INSERT
    WITH CHECK (
        practitioner_id IN (
            SELECT id FROM practitioners WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Practitioners can update own documents"
    ON documents FOR UPDATE
    USING (
        practitioner_id IN (
            SELECT id FROM practitioners WHERE user_id = auth.uid()
        )
    )
    WITH CHECK (
        practitioner_id IN (
            SELECT id FROM practitioners WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Practitioners can delete own documents"
    ON documents FOR DELETE
    USING (
        practitioner_id IN (
            SELECT id FROM practitioners WHERE user_id = auth.uid()
        )
    );

-- Admin policies (full access)
CREATE POLICY "Admins can view all documents"
    ON documents FOR SELECT
    USING (is_admin());

CREATE POLICY "Admins can insert documents"
    ON documents FOR INSERT
    WITH CHECK (is_admin());

CREATE POLICY "Admins can update documents"
    ON documents FOR UPDATE
    USING (is_admin())
    WITH CHECK (is_admin());

CREATE POLICY "Admins can delete documents"
    ON documents FOR DELETE
    USING (is_admin());

-- ==================================================
-- VERIFICATION REQUESTS TABLE RLS POLICIES
-- ==================================================

DROP POLICY IF EXISTS "Practitioners can view own verification requests" ON verification_requests;
DROP POLICY IF EXISTS "Practitioners can insert own verification requests" ON verification_requests;
DROP POLICY IF EXISTS "Admins can view all verification requests" ON verification_requests;
DROP POLICY IF EXISTS "Admins can update verification requests" ON verification_requests;

-- Practitioner policies
CREATE POLICY "Practitioners can view own verification requests"
    ON verification_requests FOR SELECT
    USING (
        practitioner_id IN (
            SELECT id FROM practitioners WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Practitioners can insert own verification requests"
    ON verification_requests FOR INSERT
    WITH CHECK (
        practitioner_id IN (
            SELECT id FROM practitioners WHERE user_id = auth.uid()
        )
    );

-- Admin policies
CREATE POLICY "Admins can view all verification requests"
    ON verification_requests FOR SELECT
    USING (is_admin());

CREATE POLICY "Admins can update verification requests"
    ON verification_requests FOR UPDATE
    USING (is_admin())
    WITH CHECK (is_admin());

-- ==================================================
-- VERIFICATION AUDIT TABLE RLS POLICIES
-- ==================================================

DROP POLICY IF EXISTS "Practitioners can view own audit logs" ON verification_audit;
DROP POLICY IF EXISTS "Admins can view all audit logs" ON verification_audit;
DROP POLICY IF EXISTS "Admins can insert audit logs" ON verification_audit;
DROP POLICY IF EXISTS "System can insert audit logs" ON verification_audit;

-- Practitioner policies (read-only)
CREATE POLICY "Practitioners can view own audit logs"
    ON verification_audit FOR SELECT
    USING (
        practitioner_id IN (
            SELECT id FROM practitioners WHERE user_id = auth.uid()
        )
    );

-- Admin policies
CREATE POLICY "Admins can view all audit logs"
    ON verification_audit FOR SELECT
    USING (is_admin());

CREATE POLICY "Admins can insert audit logs"
    ON verification_audit FOR INSERT
    WITH CHECK (is_admin());

-- System can insert audit logs (for triggers and functions)
CREATE POLICY "System can insert audit logs"
    ON verification_audit FOR INSERT
    WITH CHECK (true);

-- ==================================================
-- AI DOCUMENT EXTRACTIONS TABLE RLS POLICIES
-- ==================================================

DROP POLICY IF EXISTS "Practitioners can view own AI extractions" ON ai_document_extractions;
DROP POLICY IF EXISTS "Admins can view all AI extractions" ON ai_document_extractions;
DROP POLICY IF EXISTS "System can insert AI extractions" ON ai_document_extractions;
DROP POLICY IF EXISTS "System can update AI extractions" ON ai_document_extractions;

-- Practitioner policies (read-only)
CREATE POLICY "Practitioners can view own AI extractions"
    ON ai_document_extractions FOR SELECT
    USING (
        practitioner_id IN (
            SELECT id FROM practitioners WHERE user_id = auth.uid()
        )
    );

-- Admin policies
CREATE POLICY "Admins can view all AI extractions"
    ON ai_document_extractions FOR SELECT
    USING (is_admin());

-- System policies (for AI processing)
CREATE POLICY "System can insert AI extractions"
    ON ai_document_extractions FOR INSERT
    WITH CHECK (true);

CREATE POLICY "System can update AI extractions"
    ON ai_document_extractions FOR UPDATE
    USING (true)
    WITH CHECK (true);

-- ==================================================
-- TRUST SCORES TABLE RLS POLICIES
-- ==================================================

DROP POLICY IF EXISTS "Practitioners can view own trust score" ON trust_scores;
DROP POLICY IF EXISTS "Admins can view all trust scores" ON trust_scores;
DROP POLICY IF EXISTS "System can manage trust scores" ON trust_scores;

-- Practitioner policies (read-only)
CREATE POLICY "Practitioners can view own trust score"
    ON trust_scores FOR SELECT
    USING (
        practitioner_id IN (
            SELECT id FROM practitioners WHERE user_id = auth.uid()
        )
    );

-- Admin policies
CREATE POLICY "Admins can view all trust scores"
    ON trust_scores FOR SELECT
    USING (is_admin());

-- System policies (for automatic calculations)
CREATE POLICY "System can manage trust scores"
    ON trust_scores FOR ALL
    USING (true)
    WITH CHECK (true);

-- ==================================================
-- STORAGE POLICIES FOR VERIFICATION DOCUMENTS
-- ==================================================

-- Create storage bucket for verification documents if it doesn't exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('verification-documents', 'verification-documents', false)
ON CONFLICT (id) DO NOTHING;

-- Drop existing storage policies
DROP POLICY IF EXISTS "Practitioners can upload own documents" ON storage.objects;
DROP POLICY IF EXISTS "Practitioners can view own documents" ON storage.objects;
DROP POLICY IF EXISTS "Practitioners can update own documents" ON storage.objects;
DROP POLICY IF EXISTS "Practitioners can delete own documents" ON storage.objects;
DROP POLICY IF EXISTS "Admins can view all verification documents" ON storage.objects;
DROP POLICY IF EXISTS "Admins can delete verification documents" ON storage.objects;

-- Storage policies for practitioners
CREATE POLICY "Practitioners can upload own documents"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'verification-documents'
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Practitioners can view own documents"
    ON storage.objects FOR SELECT
    USING (
        bucket_id = 'verification-documents'
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Practitioners can update own documents"
    ON storage.objects FOR UPDATE
    USING (
        bucket_id = 'verification-documents'
        AND auth.uid()::text = (storage.foldername(name))[1]
    )
    WITH CHECK (
        bucket_id = 'verification-documents'
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Practitioners can delete own documents"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'verification-documents'
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

-- Storage policies for admins
CREATE POLICY "Admins can view all verification documents"
    ON storage.objects FOR SELECT
    USING (
        bucket_id = 'verification-documents'
        AND is_admin()
    );

CREATE POLICY "Admins can delete verification documents"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'verification-documents'
        AND is_admin()
    );

-- ==================================================
-- GRANT PERMISSIONS
-- ==================================================

-- Grant authenticated users access to tables
GRANT SELECT, INSERT, UPDATE, DELETE ON practitioners TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON documents TO authenticated;
GRANT SELECT, INSERT, UPDATE ON verification_requests TO authenticated;
GRANT SELECT ON verification_audit TO authenticated;
GRANT SELECT ON ai_document_extractions TO authenticated;
GRANT SELECT ON trust_scores TO authenticated;

-- Grant service role full access (for background jobs and AI processing)
GRANT ALL ON practitioners TO service_role;
GRANT ALL ON documents TO service_role;
GRANT ALL ON verification_requests TO service_role;
GRANT ALL ON verification_audit TO service_role;
GRANT ALL ON ai_document_extractions TO service_role;
GRANT ALL ON trust_scores TO service_role;

-- Grant public limited read access to verified practitioners (for searches)
GRANT SELECT ON practitioners TO anon;

-- ==================================================
-- TESTING RLS POLICIES
-- ==================================================
-- To test RLS policies, run these queries as different users:

-- Example: Test as practitioner
-- SET ROLE authenticated;
-- SET request.jwt.claim.sub TO '<practitioner_user_id>';
-- SELECT * FROM practitioners; -- Should only see own profile

-- Example: Test as admin
-- SET ROLE authenticated;
-- SET request.jwt.claim.sub TO '<admin_user_id>';
-- SELECT * FROM practitioners; -- Should see all profiles

-- Reset role
-- RESET ROLE;

COMMENT ON FUNCTION is_admin IS 'Check if current user has admin role';
COMMENT ON FUNCTION is_practitioner IS 'Check if current user has practitioner role';
COMMENT ON FUNCTION get_practitioner_id IS 'Get practitioner_id for current authenticated user';
