-- =====================================================
-- DIAGNOSTIC SCRIPT - CHECK PRACTITIONER & APPOINTMENT STATUS
-- =====================================================
-- Run this script to diagnose any remaining issues with
-- practitioner accounts and appointment bookings

-- =====================================================
-- 1. CHECK AUTH USERS VS PRACTITIONER PROFILES
-- =====================================================

-- Show all users with role='practitioner' and their profile status
SELECT 
    au.id as user_id,
    au.email,
    au.raw_user_meta_data->>'full_name' as full_name,
    au.raw_user_meta_data->>'role' as role,
    au.created_at as user_created,
    CASE 
        WHEN mp.id IS NOT NULL THEN '✅ Has Profile'
        ELSE '❌ MISSING PROFILE'
    END as profile_status,
    mp.id as practitioner_id,
    mp.name as practitioner_name,
    mp.verified as is_verified
FROM auth.users au
LEFT JOIN medical_practitioners mp ON mp.owner_user_id = au.id
WHERE au.raw_user_meta_data->>'role' = 'practitioner'
ORDER BY au.created_at DESC;

-- =====================================================
-- 2. CHECK FOR ORPHANED APPOINTMENTS
-- =====================================================

-- Appointments with practitioner_ids that don't exist
SELECT 
    'ORPHANED APPOINTMENTS' as issue_type,
    COUNT(*) as count
FROM appointments a
WHERE a.practitioner_id IS NOT NULL
    AND NOT EXISTS (
        SELECT 1 FROM medical_practitioners mp 
        WHERE mp.id = a.practitioner_id
    );

-- Show details of orphaned appointments
SELECT 
    a.id,
    a.booking_id,
    a.practitioner_id,
    a.practitioner_name,
    a.patient_name,
    a.appointment_date,
    a.status,
    a.created_at,
    '❌ Practitioner ID not found in medical_practitioners' as issue
FROM appointments a
WHERE a.practitioner_id IS NOT NULL
    AND NOT EXISTS (
        SELECT 1 FROM medical_practitioners mp 
        WHERE mp.id = a.practitioner_id
    )
ORDER BY a.created_at DESC
LIMIT 20;

-- =====================================================
-- 3. CHECK PRACTITIONERS WITH APPOINTMENTS
-- =====================================================

-- Show all practitioners with appointment statistics
SELECT 
    mp.id as practitioner_id,
    mp.name,
    mp.profession,
    mp.email_address,
    mp.verified,
    au.email as owner_email,
    COUNT(a.id) as total_appointments,
    COUNT(CASE WHEN a.status = 'confirmed' THEN 1 END) as confirmed_count,
    COUNT(CASE WHEN a.status = 'pending' OR a.status LIKE 'PENDING%' THEN 1 END) as pending_count,
    COUNT(CASE WHEN a.status = 'cancelled' THEN 1 END) as cancelled_count,
    MAX(a.created_at) as last_appointment_date
FROM medical_practitioners mp
LEFT JOIN auth.users au ON mp.owner_user_id = au.id
LEFT JOIN appointments a ON a.practitioner_id = mp.id
GROUP BY mp.id, mp.name, mp.profession, mp.email_address, mp.verified, au.email
ORDER BY total_appointments DESC, mp.created_at DESC;

-- =====================================================
-- 4. CHECK DATABASE TRIGGER STATUS
-- =====================================================

-- Verify if the auto-create trigger exists
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement,
    action_timing
FROM information_schema.triggers
WHERE trigger_name = 'on_auth_user_created_create_practitioner';

-- =====================================================
-- 5. CHECK FOREIGN KEY CONSTRAINTS
-- =====================================================

-- List all foreign keys on appointments table
SELECT 
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name,
    rc.update_rule,
    rc.delete_rule
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
JOIN information_schema.referential_constraints AS rc
    ON tc.constraint_name = rc.constraint_name
WHERE tc.table_name = 'appointments' 
    AND tc.constraint_type = 'FOREIGN KEY'
ORDER BY kcu.column_name;

-- =====================================================
-- 6. CHECK TABLE STRUCTURE DIFFERENCES
-- =====================================================

-- Check if both 'practitioners' and 'medical_practitioners' exist
SELECT 
    table_name,
    CASE 
        WHEN table_name = 'medical_practitioners' THEN '✅ CORRECT TABLE (used by appointments)'
        WHEN table_name = 'practitioners' THEN '⚠️ VERIFICATION SYSTEM TABLE'
        ELSE '❓ Unknown'
    END as usage
FROM information_schema.tables
WHERE table_schema = 'public'
    AND (table_name = 'practitioners' OR table_name = 'medical_practitioners')
ORDER BY table_name;

-- =====================================================
-- 7. RECENT APPOINTMENTS STATUS
-- =====================================================

-- Show last 20 appointments with full details
SELECT 
    a.booking_id,
    a.practitioner_id,
    mp.name as practitioner_name_db,
    a.practitioner_name as practitioner_name_stored,
    a.patient_name,
    a.appointment_date,
    a.appointment_time,
    a.status,
    a.payment_status,
    a.total_amount,
    a.currency,
    a.created_at,
    CASE 
        WHEN mp.id IS NOT NULL THEN '✅ Valid'
        ELSE '❌ INVALID - Missing Practitioner'
    END as validity
FROM appointments a
LEFT JOIN medical_practitioners mp ON a.practitioner_id = mp.id
ORDER BY a.created_at DESC
LIMIT 20;

-- =====================================================
-- 8. SUMMARY STATISTICS
-- =====================================================

SELECT 
    'Total Auth Users' as metric,
    COUNT(*) as count
FROM auth.users

UNION ALL

SELECT 
    'Practitioner Auth Users' as metric,
    COUNT(*) as count
FROM auth.users
WHERE raw_user_meta_data->>'role' = 'practitioner'

UNION ALL

SELECT 
    'Medical Practitioner Profiles' as metric,
    COUNT(*) as count
FROM medical_practitioners

UNION ALL

SELECT 
    'Practitioners with owner_user_id' as metric,
    COUNT(*) as count
FROM medical_practitioners
WHERE owner_user_id IS NOT NULL

UNION ALL

SELECT 
    'Practitioners without owner_user_id' as metric,
    COUNT(*) as count
FROM medical_practitioners
WHERE owner_user_id IS NULL

UNION ALL

SELECT 
    'Total Appointments' as metric,
    COUNT(*) as count
FROM appointments

UNION ALL

SELECT 
    'Valid Appointments (practitioner exists)' as metric,
    COUNT(*) as count
FROM appointments a
WHERE EXISTS (
    SELECT 1 FROM medical_practitioners mp 
    WHERE mp.id = a.practitioner_id
)

UNION ALL

SELECT 
    'Orphaned Appointments (practitioner missing)' as metric,
    COUNT(*) as count
FROM appointments a
WHERE a.practitioner_id IS NOT NULL
    AND NOT EXISTS (
        SELECT 1 FROM medical_practitioners mp 
        WHERE mp.id = a.practitioner_id
    );

-- =====================================================
-- 9. ACTION ITEMS BASED ON RESULTS
-- =====================================================

-- If you see issues, run these commands:

-- CREATE MISSING PRACTITIONER PROFILES:
-- See fix_practitioner_accounts.sql

-- FIX ORPHANED APPOINTMENTS:
-- See verify_appointments_foreign_keys.sql

-- VERIFY TRIGGER IS WORKING:
-- Create a test practitioner user and check if profile is auto-created

-- CLEAN UP LOCALSTORAGE:
-- Have users run: localStorage.removeItem('appointments')
