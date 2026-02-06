-- Fix ALL remaining enum columns in orders table
-- Run this in Supabase SQL Editor

-- 1. Find ALL enum columns in orders table
SELECT 
    column_name,
    udt_name
FROM information_schema.columns 
WHERE table_name = 'orders' 
  AND udt_name LIKE '%enum%';

-- 2. Drop policies again (in case they reference these columns)
DROP POLICY IF EXISTS "Patients can view own orders" ON orders;
DROP POLICY IF EXISTS "Patients can insert own orders" ON orders;
DROP POLICY IF EXISTS "Patients can update own orders" ON orders;

-- 3. Convert from_status column
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'orders' 
        AND column_name = 'from_status'
    ) THEN
        ALTER TABLE orders 
        ALTER COLUMN from_status TYPE VARCHAR(50) 
        USING from_status::text;
        
        RAISE NOTICE 'Changed from_status from enum to VARCHAR';
    END IF;
END $$;

-- 4. Convert to_status column (if exists)
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'orders' 
        AND column_name = 'to_status'
    ) THEN
        ALTER TABLE orders 
        ALTER COLUMN to_status TYPE VARCHAR(50) 
        USING to_status::text;
        
        RAISE NOTICE 'Changed to_status from enum to VARCHAR';
    END IF;
END $$;

-- 5. Check for any other enum columns and convert them
DO $$ 
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN 
        SELECT column_name
        FROM information_schema.columns 
        WHERE table_name = 'orders' 
          AND udt_name LIKE '%enum%'
          AND column_name NOT IN ('status', 'payment_status', 'from_status', 'to_status')
    LOOP
        EXECUTE format('ALTER TABLE orders ALTER COLUMN %I TYPE VARCHAR(50) USING %I::text', rec.column_name, rec.column_name);
        RAISE NOTICE 'Changed % from enum to VARCHAR', rec.column_name;
    END LOOP;
END $$;

-- 6. Recreate RLS policies
CREATE POLICY "Patients can view own orders"
ON orders FOR SELECT
USING (auth.uid() = patient_id);

CREATE POLICY "Patients can insert own orders"
ON orders FOR INSERT
WITH CHECK (auth.uid() = patient_id);

CREATE POLICY "Patients can update own orders"
ON orders FOR UPDATE
USING (auth.uid() = patient_id);

-- 7. Verify no more enums
SELECT 
    column_name,
    data_type,
    udt_name
FROM information_schema.columns 
WHERE table_name = 'orders' 
  AND column_name IN ('status', 'payment_status', 'from_status', 'to_status')
ORDER BY column_name;

SELECT 'All enum columns converted successfully!' as result;
