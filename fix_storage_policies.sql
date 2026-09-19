-- ==================================================
-- FIX STORAGE BUCKET POLICIES FOR PRACTITIONER UPLOADS
-- ==================================================
-- Run this in Supabase SQL Editor to fix RLS policy errors

-- ==================================================
-- 1. CREATE STORAGE BUCKETS
-- ==================================================

-- Create verification-documents bucket (public for admin viewing)
INSERT INTO storage.buckets (id, name, public)
VALUES ('verification-documents', 'verification-documents', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Create practitioner-profiles bucket (public for profile pictures)
INSERT INTO storage.buckets (id, name, public)
VALUES ('practitioner-profiles', 'practitioner-profiles', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- ==================================================
-- 2. DROP EXISTING POLICIES (Clean slate)
-- ==================================================

-- Drop verification-documents policies
DROP POLICY IF EXISTS "Practitioners can upload own documents" ON storage.objects;
DROP POLICY IF EXISTS "Practitioners can view own documents" ON storage.objects;
DROP POLICY IF EXISTS "Practitioners can update own documents" ON storage.objects;
DROP POLICY IF EXISTS "Practitioners can delete own documents" ON storage.objects;
DROP POLICY IF EXISTS "Admins can view all verification documents" ON storage.objects;
DROP POLICY IF EXISTS "Admins can delete verification documents" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can view verification documents" ON storage.objects;

-- Drop practitioner-profiles policies
DROP POLICY IF EXISTS "Practitioners can upload own profiles" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can view profile pictures" ON storage.objects;
DROP POLICY IF EXISTS "Practitioners can update own profiles" ON storage.objects;
DROP POLICY IF EXISTS "Practitioners can delete own profiles" ON storage.objects;

-- ==================================================
-- 3. VERIFICATION-DOCUMENTS POLICIES
-- ==================================================

-- Upload policy: Practitioners can upload to their own folder
CREATE POLICY "Practitioners can upload own documents"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'verification-documents'
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

-- Select policy: Practitioners can view their own documents
CREATE POLICY "Practitioners can view own documents"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (
        bucket_id = 'verification-documents'
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

-- Update policy: Practitioners can update their own documents
CREATE POLICY "Practitioners can update own documents"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (
        bucket_id = 'verification-documents'
        AND auth.uid()::text = (storage.foldername(name))[1]
    )
    WITH CHECK (
        bucket_id = 'verification-documents'
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

-- Delete policy: Practitioners can delete their own documents
CREATE POLICY "Practitioners can delete own documents"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'verification-documents'
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

-- Public/Admin can view verification documents (needed for admin review)
CREATE POLICY "Anyone can view verification documents"
    ON storage.objects FOR SELECT
    TO public
    USING (bucket_id = 'verification-documents');

-- ==================================================
-- 4. PRACTITIONER-PROFILES POLICIES  
-- ==================================================

-- Upload policy: Practitioners can upload to their own folder
CREATE POLICY "Practitioners can upload own profiles"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'practitioner-profiles'
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

-- Select policy: Anyone can view profile pictures (public bucket)
CREATE POLICY "Anyone can view profile pictures"
    ON storage.objects FOR SELECT
    TO public
    USING (bucket_id = 'practitioner-profiles');

-- Update policy: Practitioners can update their own profiles
CREATE POLICY "Practitioners can update own profiles"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (
        bucket_id = 'practitioner-profiles'
        AND auth.uid()::text = (storage.foldername(name))[1]
    )
    WITH CHECK (
        bucket_id = 'practitioner-profiles'
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

-- Delete policy: Practitioners can delete their own profiles
CREATE POLICY "Practitioners can delete own profiles"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'practitioner-profiles'
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

-- ==================================================
-- 5. VERIFICATION
-- ==================================================

-- Verify policies are created
SELECT 
    schemaname, 
    tablename, 
    policyname, 
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies 
WHERE tablename = 'objects'
AND policyname LIKE '%Practitioners%'
ORDER BY policyname;

-- Verify buckets are created
SELECT id, name, public FROM storage.buckets 
WHERE id IN ('verification-documents', 'practitioner-profiles');
