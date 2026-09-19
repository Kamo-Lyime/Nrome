-- =====================================================
-- DIAGNOSE AND FIX PRESCRIPTIONS TABLE
-- =====================================================

-- =====================================================
-- STEP 1: Check what columns actually exist
-- =====================================================

SELECT 
    column_name,
    data_type,
    character_maximum_length,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'prescriptions'
    AND table_schema = 'public'
ORDER BY ordinal_position;

-- =====================================================
-- STEP 2: Add missing columns if they don't exist
-- =====================================================

-- Add doctor_name if missing
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'prescriptions' 
        AND column_name = 'doctor_name'
    ) THEN
        ALTER TABLE prescriptions ADD COLUMN doctor_name TEXT;
        RAISE NOTICE 'Added doctor_name column';
    ELSE
        RAISE NOTICE 'doctor_name column already exists';
    END IF;
END $$;

-- Add prescription_date if missing
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'prescriptions' 
        AND column_name = 'prescription_date'
    ) THEN
        ALTER TABLE prescriptions ADD COLUMN prescription_date DATE;
        RAISE NOTICE 'Added prescription_date column';
    ELSE
        RAISE NOTICE 'prescription_date column already exists';
    END IF;
END $$;

-- Add prescription_expiry if missing
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'prescriptions' 
        AND column_name = 'prescription_expiry'
    ) THEN
        ALTER TABLE prescriptions ADD COLUMN prescription_expiry DATE;
        RAISE NOTICE 'Added prescription_expiry column';
    ELSE
        RAISE NOTICE 'prescription_expiry column already exists';
    END IF;
END $$;

-- Add refills_allowed if missing
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'prescriptions' 
        AND column_name = 'refills_allowed'
    ) THEN
        ALTER TABLE prescriptions ADD COLUMN refills_allowed INTEGER DEFAULT 0 CHECK (refills_allowed >= 0 AND refills_allowed <= 12);
        RAISE NOTICE 'Added refills_allowed column';
    ELSE
        RAISE NOTICE 'refills_allowed column already exists';
    END IF;
END $$;

-- Add notes if missing
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'prescriptions' 
        AND column_name = 'notes'
    ) THEN
        ALTER TABLE prescriptions ADD COLUMN notes TEXT;
        RAISE NOTICE 'Added notes column';
    ELSE
        RAISE NOTICE 'notes column already exists';
    END IF;
END $$;

-- Add file_name if missing
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'prescriptions' 
        AND column_name = 'file_name'
    ) THEN
        ALTER TABLE prescriptions ADD COLUMN file_name TEXT;
        RAISE NOTICE 'Added file_name column';
    ELSE
        RAISE NOTICE 'file_name column already exists';
    END IF;
END $$;

-- Add file_data if missing
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'prescriptions' 
        AND column_name = 'file_data'
    ) THEN
        ALTER TABLE prescriptions ADD COLUMN file_data TEXT;
        RAISE NOTICE 'Added file_data column';
    ELSE
        RAISE NOTICE 'file_data column already exists';
    END IF;
END $$;

-- Add status if missing
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'prescriptions' 
        AND column_name = 'status'
    ) THEN
        ALTER TABLE prescriptions ADD COLUMN status TEXT DEFAULT 'Pending Verification';
        RAISE NOTICE 'Added status column';
    ELSE
        RAISE NOTICE 'status column already exists';
    END IF;
END $$;

-- Add verified if missing
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'prescriptions' 
        AND column_name = 'verified'
    ) THEN
        ALTER TABLE prescriptions ADD COLUMN verified BOOLEAN DEFAULT FALSE;
        RAISE NOTICE 'Added verified column';
    ELSE
        RAISE NOTICE 'verified column already exists';
    END IF;
END $$;

-- Add upload_date if missing
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'prescriptions' 
        AND column_name = 'upload_date'
    ) THEN
        ALTER TABLE prescriptions ADD COLUMN upload_date TIMESTAMPTZ DEFAULT NOW();
        RAISE NOTICE 'Added upload_date column';
    ELSE
        RAISE NOTICE 'upload_date column already exists';
    END IF;
END $$;

-- =====================================================
-- STEP 3: Verify all columns now exist
-- =====================================================

SELECT 
    column_name,
    data_type,
    CASE 
        WHEN column_name IN ('doctor_name', 'prescription_date', 'prescription_expiry', 'refills_allowed', 
                             'notes', 'file_name', 'file_data', 'status', 'verified', 'upload_date',
                             'patient_id', 'uploaded_by', 'patient_name', 'patient_email') 
        THEN '✅ Required column present'
        ELSE 'ℹ️ Optional column'
    END as status
FROM information_schema.columns
WHERE table_name = 'prescriptions'
    AND table_schema = 'public'
ORDER BY ordinal_position;

-- =====================================================
-- STEP 4: Notify to refresh Supabase schema cache
-- =====================================================

SELECT 'Run this in Supabase Dashboard: Settings > API > Reload schema cache' as instruction;

-- =====================================================
-- COMPLETE! ✅
-- =====================================================
-- ✅ Checked all columns
-- ✅ Added any missing columns
-- ⚠️ IMPORTANT: Go to Supabase Dashboard > Settings > API > Click "Reload schema cache" button
-- 
-- After reloading schema cache, try uploading prescription again
-- =====================================================
