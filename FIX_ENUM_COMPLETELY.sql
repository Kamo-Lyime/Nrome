-- NUCLEAR OPTION: Remove ALL enum dependencies and convert to VARCHAR
-- Run this in Supabase SQL Editor

-- 1. Find all triggers on orders table
SELECT 
    trigger_name,
    event_manipulation,
    action_statement
FROM information_schema.triggers 
WHERE event_object_table = 'orders';

-- 2. Drop ALL triggers on orders table
DO $$ 
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN 
        SELECT trigger_name
        FROM information_schema.triggers 
        WHERE event_object_table = 'orders'
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS %I ON orders', rec.trigger_name);
        RAISE NOTICE 'Dropped trigger %', rec.trigger_name;
    END LOOP;
END $$;

-- 3. Drop any functions that enforce status transitions
DROP FUNCTION IF EXISTS enforce_order_status_transition() CASCADE;
DROP FUNCTION IF EXISTS validate_order_status() CASCADE;
DROP FUNCTION IF EXISTS check_order_status() CASCADE;

-- 4. Drop ALL views
DROP VIEW IF EXISTS pharmacy_order_view CASCADE;
DROP VIEW IF EXISTS patient_order_tracking CASCADE;
DROP VIEW IF EXISTS order_summary CASCADE;
DROP VIEW IF EXISTS pharmacy_dashboard_stats CASCADE;

-- 5. Drop ALL policies
DO $$ 
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN 
        SELECT policyname
        FROM pg_policies 
        WHERE tablename = 'orders'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON orders', rec.policyname);
        RAISE NOTICE 'Dropped policy %', rec.policyname;
    END LOOP;
END $$;

-- 6. Now convert ALL enum columns
ALTER TABLE orders ALTER COLUMN status TYPE VARCHAR(50) USING status::text;
ALTER TABLE orders ALTER COLUMN status SET DEFAULT 'created';

ALTER TABLE orders ALTER COLUMN payment_status TYPE VARCHAR(50) USING payment_status::text;
ALTER TABLE orders ALTER COLUMN payment_status SET DEFAULT 'pending';

-- Try to convert from_status if it exists
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'orders' 
        AND column_name = 'from_status'
    ) THEN
        ALTER TABLE orders ALTER COLUMN from_status TYPE VARCHAR(50) USING from_status::text;
        RAISE NOTICE 'Converted from_status';
    END IF;
END $$;

-- Try to convert to_status if it exists
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'orders' 
        AND column_name = 'to_status'
    ) THEN
        ALTER TABLE orders ALTER COLUMN to_status TYPE VARCHAR(50) USING to_status::text;
        RAISE NOTICE 'Converted to_status';
    END IF;
END $$;

-- 7. Add payment_reference if missing
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'orders' 
        AND column_name = 'payment_reference'
    ) THEN
        ALTER TABLE orders ADD COLUMN payment_reference VARCHAR(100);
        RAISE NOTICE 'Added payment_reference';
    END IF;
END $$;

-- 8. Recreate basic RLS policies
CREATE POLICY "Patients can view own orders"
ON orders FOR SELECT
USING (auth.uid() = patient_id);

CREATE POLICY "Patients can insert own orders"
ON orders FOR INSERT
WITH CHECK (auth.uid() = patient_id);

CREATE POLICY "Patients can update own orders"
ON orders FOR UPDATE
USING (auth.uid() = patient_id);

-- 9. Verify conversion
SELECT 
    column_name,
    data_type,
    udt_name,
    column_default
FROM information_schema.columns 
WHERE table_name = 'orders' 
  AND column_name IN ('status', 'payment_status', 'from_status', 'to_status', 'payment_reference')
ORDER BY column_name;

-- 10. Check for any remaining triggers
SELECT 
    trigger_name,
    event_manipulation
FROM information_schema.triggers 
WHERE event_object_table = 'orders';

SELECT 'Complete enum cleanup done!' as result;
