-- =====================================================
-- FIX USER DELETION ISSUES - COMPREHENSIVE VERSION
-- =====================================================
-- This script fixes the "Database error deleting user" issue
-- by automatically finding and updating ALL foreign key constraints
-- =====================================================

-- =====================================================
-- STEP 1: Find and fix ALL foreign keys to auth.users automatically
-- =====================================================

DO $$
DECLARE
    constraint_record RECORD;
    sql_command TEXT;
BEGIN
    -- Loop through ALL foreign keys that reference auth.users
    FOR constraint_record IN 
        SELECT 
            tc.table_name,
            tc.constraint_name,
            kcu.column_name,
            rc.delete_rule
        FROM information_schema.table_constraints AS tc 
        JOIN information_schema.key_column_usage AS kcu
            ON tc.constraint_name = kcu.constraint_name
            AND tc.table_schema = kcu.table_schema
        JOIN information_schema.constraint_column_usage AS ccu
            ON ccu.constraint_name = tc.constraint_name
            AND ccu.table_schema = tc.table_schema
        JOIN information_schema.referential_constraints AS rc
            ON tc.constraint_name = rc.constraint_name
            AND tc.table_schema = rc.constraint_schema
        WHERE tc.constraint_type = 'FOREIGN KEY'
            AND ccu.table_schema = 'auth'
            AND ccu.table_name = 'users'
            AND tc.table_schema = 'public'
            AND rc.delete_rule != 'CASCADE'  -- Only fix constraints that aren't CASCADE
    LOOP
        RAISE NOTICE 'Fixing constraint: % on table %', constraint_record.constraint_name, constraint_record.table_name;
        
        -- Drop the old constraint
        sql_command := format('ALTER TABLE %I DROP CONSTRAINT IF EXISTS %I',
            constraint_record.table_name,
            constraint_record.constraint_name
        );
        EXECUTE sql_command;
        
        -- Recreate with CASCADE DELETE (except for uploaded_by and practitioner references)
        IF constraint_record.column_name LIKE '%uploaded_by%' OR 
           constraint_record.column_name LIKE '%practitioner_user%' THEN
            -- Use SET NULL for uploaded_by and practitioner references
            sql_command := format('ALTER TABLE %I ADD CONSTRAINT %I FOREIGN KEY (%I) REFERENCES auth.users(id) ON DELETE SET NULL',
                constraint_record.table_name,
                constraint_record.constraint_name,
                constraint_record.column_name
            );
        ELSE
            -- Use CASCADE for all other user references
            sql_command := format('ALTER TABLE %I ADD CONSTRAINT %I FOREIGN KEY (%I) REFERENCES auth.users(id) ON DELETE CASCADE',
                constraint_record.table_name,
                constraint_record.constraint_name,
                constraint_record.column_name
            );
        END IF;
        
        EXECUTE sql_command;
        RAISE NOTICE 'Fixed: %', constraint_record.constraint_name;
    END LOOP;
    
    RAISE NOTICE 'All foreign key constraints have been updated!';
END $$;

-- =====================================================
-- STEP 2: DISABLE RLS temporarily if needed (optional)
-- =====================================================
-- Sometimes RLS policies can interfere with deletion
-- Uncomment if you need to disable RLS on specific tables

/*
ALTER TABLE prescriptions DISABLE ROW LEVEL SECURITY;
ALTER TABLE medication_orders DISABLE ROW LEVEL SECURITY;
-- Add other tables as needed
*/

-- =====================================================
-- STEP 3: Ensure all tables have necessary user_id columns
-- =====================================================

-- Prescriptions table
ALTER TABLE prescriptions 
    ADD COLUMN IF NOT EXISTS user_id UUID,
    ADD COLUMN IF NOT EXISTS uploaded_by_user_id UUID;

-- Medication orders table
ALTER TABLE medication_orders 
    ADD COLUMN IF NOT EXISTS user_id UUID;

-- Appointments table (if exists)
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'appointments') THEN
        EXECUTE 'ALTER TABLE appointments ADD COLUMN IF NOT EXISTS patient_id UUID';
        EXECUTE 'ALTER TABLE appointments ADD COLUMN IF NOT EXISTS practitioner_user_id UUID';
    END IF;
END $$;

-- Medical practitioners table (if exists)
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'medical_practitioners') THEN
        EXECUTE 'ALTER TABLE medical_practitioners ADD COLUMN IF NOT EXISTS user_id UUID';
    END IF;
END $$;

-- Triage table (if exists)
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'triage') THEN
        EXECUTE 'ALTER TABLE triage ADD COLUMN IF NOT EXISTS user_id UUID';
    END IF;
END $$;

-- Messages table (if exists)
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'messages') THEN
        EXECUTE 'ALTER TABLE messages ADD COLUMN IF NOT EXISTS sender_id UUID';
        EXECUTE 'ALTER TABLE messages ADD COLUMN IF NOT EXISTS recipient_id UUID';
    END IF;
END $$;

-- Notifications table (if exists)
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'notifications') THEN
        EXECUTE 'ALTER TABLE notifications ADD COLUMN IF NOT EXISTS user_id UUID';
    END IF;
END $$;

-- =====================================================
-- STEP 4: Create function to safely delete user and all related data
-- =====================================================

CREATE OR REPLACE FUNCTION delete_user_and_data(user_uuid UUID)
RETURNS JSON AS $$
DECLARE
    deleted_counts JSON;
    prescriptions_count INTEGER;
    orders_count INTEGER;
    appointments_count INTEGER;
    messages_count INTEGER;
    notifications_count INTEGER;
    practitioners_count INTEGER;
    triage_count INTEGER;
BEGIN
    -- Count records before deletion (for reporting)
    SELECT COUNT(*) INTO prescriptions_count FROM prescriptions WHERE user_id = user_uuid OR uploaded_by_user_id = user_uuid;
    SELECT COUNT(*) INTO orders_count FROM medication_orders WHERE user_id = user_uuid;
    
    -- Appointments (if exists)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'appointments') THEN
        EXECUTE 'SELECT COUNT(*) FROM appointments WHERE patient_id = $1' INTO appointments_count USING user_uuid;
    ELSE
        appointments_count := 0;
    END IF;
    
    -- Messages (if exists)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'messages') THEN
        EXECUTE 'SELECT COUNT(*) FROM messages WHERE sender_id = $1 OR recipient_id = $1' INTO messages_count USING user_uuid;
    ELSE
        messages_count := 0;
    END IF;
    
    -- Notifications (if exists)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'notifications') THEN
        EXECUTE 'SELECT COUNT(*) FROM notifications WHERE user_id = $1' INTO notifications_count USING user_uuid;
    ELSE
        notifications_count := 0;
    END IF;
    
    -- Practitioners (if exists)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'medical_practitioners') THEN
        EXECUTE 'SELECT COUNT(*) FROM medical_practitioners WHERE user_id = $1' INTO practitioners_count USING user_uuid;
    ELSE
        practitioners_count := 0;
    END IF;
    
    -- Triage (if exists)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'triage') THEN
        EXECUTE 'SELECT COUNT(*) FROM triage WHERE user_id = $1' INTO triage_count USING user_uuid;
    ELSE
        triage_count := 0;
    END IF;
    
    -- Delete user from auth.users (CASCADE will handle related records)
    DELETE FROM auth.users WHERE id = user_uuid;
    
    -- Return deletion summary
    deleted_counts := json_build_object(
        'user_id', user_uuid,
        'deleted', TRUE,
        'prescriptions_deleted', prescriptions_count,
        'orders_deleted', orders_count,
        'appointments_deleted', appointments_count,
        'messages_deleted', messages_count,
        'notifications_deleted', notifications_count,
        'practitioners_deleted', practitioners_count,
        'triage_deleted', triage_count
    );
    
    RETURN deleted_counts;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- STEP 5: Grant necessary permissions
-- =====================================================

-- Grant execute permission to authenticated users (optional - for admin use only)
-- GRANT EXECUTE ON FUNCTION delete_user_and_data(UUID) TO authenticated;

-- =====================================================
-- STEP 6: VERIFICATION - Run this to check all constraints
-- =====================================================
-- Run this to verify the constraints were updated:
/*
SELECT
    tc.table_name, 
    tc.constraint_name, 
    kcu.column_name,
    rc.delete_rule
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.referential_constraints AS rc
    ON tc.constraint_name = rc.constraint_name
    AND tc.table_schema = rc.constraint_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY' 
    AND ccu.table_schema = 'auth'
    AND ccu.table_name = 'users'
    AND tc.table_schema = 'public'
ORDER BY tc.table_name, rc.delete_rule, tc.constraint_name;
*/

-- =====================================================
-- USAGE EXAMPLES
-- =====================================================
/*
-- To delete a user and all their data:
SELECT delete_user_and_data('user-uuid-here');

-- To delete a user via Supabase Auth (now works automatically):
-- Just use the Supabase Dashboard > Authentication > Users > Delete
-- The CASCADE constraints will automatically clean up related data
*/
