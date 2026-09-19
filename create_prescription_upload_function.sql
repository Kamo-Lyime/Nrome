-- =====================================================
-- CREATE PRESCRIPTION UPLOAD FUNCTION
-- =====================================================
-- This bypasses PostgREST schema cache issues by using a SQL function

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS upload_prescription_for_patient;

-- Create function to insert prescription
CREATE OR REPLACE FUNCTION upload_prescription_for_patient(
    p_file_name TEXT,
    p_file_data TEXT,
    p_doctor_name TEXT,
    p_prescription_date DATE,
    p_prescription_expiry DATE,
    p_refills_allowed INTEGER,
    p_notes TEXT,
    p_patient_id UUID DEFAULT NULL,  -- Allow NULL for patients not yet registered
    p_uploaded_by UUID DEFAULT NULL, -- Allow NULL (though should always have practitioner ID)
    p_patient_name TEXT DEFAULT NULL,
    p_patient_email TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSON;
    new_id UUID;
    prescription_num TEXT;
BEGIN
    -- Validate required fields
    IF p_file_name IS NULL OR p_file_name = '' THEN
        RAISE EXCEPTION 'File name is required';
    END IF;
    
    IF p_doctor_name IS NULL OR p_doctor_name = '' THEN
        RAISE EXCEPTION 'Doctor name is required';
    END IF;
    
    IF p_prescription_date IS NULL THEN
        RAISE EXCEPTION 'Prescription date is required';
    END IF;
    
    IF p_patient_email IS NULL OR p_patient_email = '' THEN
        RAISE EXCEPTION 'Patient email is required';
    END IF;
    
    -- Generate a new UUID for the prescription
    new_id := gen_random_uuid();
    
    -- Generate prescription number
    prescription_num := 'RX-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || UPPER(SUBSTRING(MD5(RANDOM()::TEXT) FROM 1 FOR 8));
    
    -- Insert the prescription with status = 'verified' for practitioner uploads
    INSERT INTO prescriptions (
        id,
        prescription_number,
        issue_date,
        valid_from,
        valid_until,
        file_name,
        file_data,
        doctor_name,
        prescription_date,
        prescription_expiry,
        refills_allowed,
        notes,
        status,
        verified,
        upload_date,
        created_at,
        updated_at,
        patient_id,
        uploaded_by,
        patient_name,
        patient_email
    ) VALUES (
        new_id,
        prescription_num,
        p_prescription_date,  -- Use prescription_date as issue_date
        p_prescription_date,  -- Use prescription_date as valid_from
        COALESCE(p_prescription_expiry, p_prescription_date + INTERVAL '30 days'), -- Default to 30 days if no expiry
        p_file_name,
        p_file_data,
        p_doctor_name,
        p_prescription_date,
        COALESCE(p_prescription_expiry, p_prescription_date + INTERVAL '30 days'),
        COALESCE(p_refills_allowed, 0),
        COALESCE(p_notes, ''),
        'verified'::prescription_status,  -- Set status to verified for practitioner uploads
        true,  -- Practitioner-uploaded prescriptions are auto-verified
        NOW(),
        NOW(),
        NOW(),
        p_patient_id,
        p_uploaded_by,
        p_patient_name,
        p_patient_email
    );
    
    -- Return the inserted ID
    SELECT json_build_object('id', new_id, 'prescription_number', prescription_num, 'success', true) INTO result;
    
    RETURN result;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION upload_prescription_for_patient TO authenticated;

-- =====================================================
-- COMPLETE! ✅
-- =====================================================
-- ✅ Created upload_prescription_for_patient function
-- ✅ Generates prescription_number automatically
-- ✅ Sets status='verified' for practitioner uploads
-- ✅ Allows NULL for patient_id (manual patient entry)
-- ✅ Validates required fields
-- ✅ This bypasses PostgREST schema cache issues
-- 
-- Re-run this script in Supabase SQL Editor
-- Then hard refresh dashboard.html (Ctrl+Shift+R)
-- Then try uploading prescription again
-- =====================================================
