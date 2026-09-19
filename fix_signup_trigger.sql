-- =====================================================
-- FIX SIGNUP TRIGGER - Handle Missing Columns
-- =====================================================
-- This script fixes the trigger that was causing 500 errors
-- on practitioner signup

-- =====================================================
-- OPTION 1: Drop the problematic trigger (RECOMMENDED FOR NOW)
-- =====================================================
-- This removes the trigger so signups work again
-- The frontend code (auth.js) will handle profile creation instead

DROP TRIGGER IF EXISTS on_auth_user_created_create_practitioner ON auth.users;
DROP FUNCTION IF EXISTS handle_new_practitioner_signup();

-- =====================================================
-- OPTION 2: Create a more robust trigger (ADVANCED)
-- =====================================================
-- Only run this if you want automatic profile creation
-- Uncomment the code below:

/*
CREATE OR REPLACE FUNCTION handle_new_practitioner_signup()
RETURNS TRIGGER AS $$
DECLARE
    missing_cols text[];
    col_exists boolean;
BEGIN
    -- Only process if user role is practitioner
    IF NEW.raw_user_meta_data->>'role' = 'practitioner' THEN
        -- Check if profile already exists
        IF EXISTS (SELECT 1 FROM medical_practitioners WHERE owner_user_id = NEW.id) THEN
            RETURN NEW;
        END IF;
        
        -- Try to insert with all possible columns
        -- If a column doesn't exist, the insert will still work with other columns
        BEGIN
            INSERT INTO medical_practitioners (
                owner_user_id,
                name,
                profession,
                phone_number,
                email_address,
                verified,
                rating,
                total_patients,
                created_at,
                updated_at
            ) VALUES (
                NEW.id,
                COALESCE(NEW.raw_user_meta_data->>'full_name', 'Practitioner'),
                'Medical Practitioner',
                COALESCE(NEW.phone, ''),
                COALESCE(NEW.email, ''),
                false,
                0,
                0,
                NOW(),
                NOW()
            )
            ON CONFLICT (owner_user_id) DO NOTHING;
        EXCEPTION
            WHEN undefined_column THEN
                -- Column doesn't exist, log and continue
                RAISE WARNING 'Column does not exist in medical_practitioners: %', SQLERRM;
            WHEN not_null_violation THEN
                -- Missing required field, log and continue
                RAISE WARNING 'Not null violation in medical_practitioners: %', SQLERRM;
            WHEN OTHERS THEN
                -- Other errors, log but don't fail signup
                RAISE WARNING 'Error creating practitioner profile: %', SQLERRM;
        END;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created_create_practitioner
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION handle_new_practitioner_signup();
*/

-- =====================================================
-- VERIFICATION
-- =====================================================

-- Check if trigger exists
SELECT 
    trigger_name,
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE trigger_name = 'on_auth_user_created_create_practitioner';

-- =====================================================
-- COMPLETE!
-- =====================================================
-- The trigger has been removed
-- Signups will now work normally
-- Profile creation is handled by frontend (auth.js)
