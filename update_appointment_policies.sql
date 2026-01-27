-- =====================================================
-- MIGRATION: Update Appointment Policies for Practitioner-Patient Linking
-- =====================================================
-- This migration updates the Row Level Security policies for the appointments table
-- to properly separate patient and practitioner views of appointment data.
--
-- PURPOSE:
-- 1. Patients can see appointments they created (via user_id)
-- 2. Practitioners can see appointments booked with them (via practitioner_id)
-- 3. Practitioners can update status of appointments booked with them
-- 4. Maintains data security while enabling proper two-way visibility
--
-- Run this in Supabase SQL Editor to update your existing database
-- =====================================================

-- Drop existing overly permissive policies
DROP POLICY IF EXISTS "Allow all operations on appointments" ON appointments;
DROP POLICY IF EXISTS "Allow patients to view their appointments" ON appointments;
DROP POLICY IF EXISTS "Allow practitioners to view their appointments" ON appointments;
DROP POLICY IF EXISTS "Allow patients to create appointments" ON appointments;
DROP POLICY IF EXISTS "Allow practitioners to update appointments" ON appointments;

-- Patients can view appointments they created
CREATE POLICY "Allow patients to view their appointments" 
ON appointments 
FOR SELECT 
USING (auth.uid() = user_id);

-- Practitioners can view appointments booked with them
-- Matches logged-in user to their practitioner record, then shows appointments with that practitioner_id
CREATE POLICY "Allow practitioners to view their appointments" 
ON appointments 
FOR SELECT 
USING (
    practitioner_id IN (
        SELECT id FROM medical_practitioners WHERE owner_user_id = auth.uid()
    )
);

-- Anyone authenticated can create appointments (as a patient)
CREATE POLICY "Allow patients to create appointments" 
ON appointments 
FOR INSERT 
WITH CHECK (auth.uid() = user_id);

-- Ensure updated_at column exists (for existing databases)
ALTER TABLE appointments ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Add columns for rescheduling and cancellation tracking
ALTER TABLE appointments ADD COLUMN IF NOT EXISTS rescheduled_date DATE;
ALTER TABLE appointments ADD COLUMN IF NOT EXISTS rescheduled_time TEXT;
ALTER TABLE appointments ADD COLUMN IF NOT EXISTS cancellation_reason TEXT;
ALTER TABLE appointments ADD COLUMN IF NOT EXISTS practitioner_notes TEXT;

-- Update default status to 'pending' so practitioners must confirm bookings
ALTER TABLE appointments ALTER COLUMN status SET DEFAULT 'pending';

-- =====================================================
-- UPDATE PRESCRIPTIONS TABLE FOR PRACTITIONER UPLOADS
-- =====================================================

-- Add new columns for practitioner-uploaded prescriptions
ALTER TABLE prescriptions ADD COLUMN IF NOT EXISTS practitioner_id UUID REFERENCES medical_practitioners(id);
ALTER TABLE prescriptions ADD COLUMN IF NOT EXISTS uploaded_by_user_id UUID REFERENCES auth.users(id);
ALTER TABLE prescriptions ADD COLUMN IF NOT EXISTS patient_name TEXT;
ALTER TABLE prescriptions ADD COLUMN IF NOT EXISTS patient_email TEXT;

-- Create indices for faster queries
CREATE INDEX IF NOT EXISTS idx_prescriptions_practitioner ON prescriptions(practitioner_id);
CREATE INDEX IF NOT EXISTS idx_prescriptions_patient_email ON prescriptions(patient_email);

-- =====================================================
-- UPDATE PRESCRIPTION RLS POLICIES
-- =====================================================

-- Drop existing overly permissive prescription policies
DROP POLICY IF EXISTS "Allow all operations on prescriptions" ON prescriptions;
DROP POLICY IF EXISTS "Allow patients to view their prescriptions" ON prescriptions;
DROP POLICY IF EXISTS "Allow practitioners to view their prescriptions" ON prescriptions;
DROP POLICY IF EXISTS "Allow practitioners to upload prescriptions" ON prescriptions;

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

-- Practitioners can update appointments booked with them
-- This allows them to change status, add notes, etc.
CREATE POLICY "Allow practitioners to update appointments" 
ON appointments 
FOR UPDATE 
USING (
    practitioner_id IN (
        SELECT id FROM medical_practitioners WHERE owner_user_id = auth.uid()
    )
);

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================
-- Run these to verify the policies are working:

-- 1. Check policies are created:
-- SELECT * FROM pg_policies WHERE tablename = 'appointments';

-- 2. Test as patient - should see appointments you created:
-- SELECT * FROM appointments WHERE user_id = auth.uid();

-- 3. Test as practitioner - should see appointments booked with you:
-- SELECT a.* FROM appointments a
-- JOIN medical_practitioners mp ON a.practitioner_id = mp.id
-- WHERE mp.owner_user_id = auth.uid();
