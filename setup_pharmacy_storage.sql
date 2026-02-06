-- Create Supabase Storage bucket for pharmacy verification documents
-- Run this in Supabase SQL Editor

-- Create the storage bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('pharmacy-documents', 'pharmacy-documents', false)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for pharmacy-documents bucket

-- Allow authenticated users to upload their own pharmacy documents
CREATE POLICY "Pharmacy managers can upload documents"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'pharmacy-documents' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow authenticated users to view their own documents
CREATE POLICY "Pharmacy managers can view own documents"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'pharmacy-documents' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow admins to view all pharmacy documents
CREATE POLICY "Admins can view all pharmacy documents"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'pharmacy-documents' AND
  EXISTS (
    SELECT 1 FROM user_role_assignments
    WHERE user_id = auth.uid()
    AND role = 'admin'
    AND is_active = true
  )
);

-- Allow admins to delete pharmacy documents if needed
CREATE POLICY "Admins can delete pharmacy documents"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'pharmacy-documents' AND
  EXISTS (
    SELECT 1 FROM user_role_assignments
    WHERE user_id = auth.uid()
    AND role = 'admin'
    AND is_active = true
  )
);

-- Add columns to pharmacy_verifications for document URLs
ALTER TABLE pharmacy_verifications
  ADD COLUMN IF NOT EXISTS sapc_document_url TEXT,
  ADD COLUMN IF NOT EXISTS license_document_url TEXT,
  ADD COLUMN IF NOT EXISTS bank_document_url TEXT;

COMMENT ON COLUMN pharmacy_verifications.sapc_document_url IS 'Storage URL for SAPC registration certificate';
COMMENT ON COLUMN pharmacy_verifications.license_document_url IS 'Storage URL for business license document';
COMMENT ON COLUMN pharmacy_verifications.bank_document_url IS 'Storage URL for bank account confirmation';
