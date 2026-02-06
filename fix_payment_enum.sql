-- Check and fix payment_status enum type
-- Run this in Supabase SQL Editor

-- 1. Check current enum values for payment_status
SELECT 
    t.typname AS enum_name,
    e.enumlabel AS enum_value
FROM pg_type t 
JOIN pg_enum e ON t.oid = e.enumtypid  
WHERE t.typname LIKE '%payment%'
ORDER BY e.enumsortorder;

-- 2. Check the actual column type
SELECT 
    column_name, 
    data_type, 
    udt_name
FROM information_schema.columns 
WHERE table_name = 'orders' 
  AND column_name = 'payment_status';

-- 3. If it's an enum, alter it to add 'paid' value OR change it to VARCHAR
-- Option A: Add 'paid' to existing enum (if enum exists)
-- ALTER TYPE payment_status_enum ADD VALUE IF NOT EXISTS 'paid';

-- Option B: Change column to VARCHAR (RECOMMENDED - more flexible)
DO $$ 
BEGIN
    -- Check if column is enum type
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'orders' 
        AND column_name = 'payment_status'
        AND udt_name LIKE '%enum%'
    ) THEN
        -- Change from enum to VARCHAR
        ALTER TABLE orders 
        ALTER COLUMN payment_status TYPE VARCHAR(50) 
        USING payment_status::text;
        
        RAISE NOTICE 'Changed payment_status from enum to VARCHAR';
    END IF;
END $$;

-- 4. Set default value
ALTER TABLE orders 
ALTER COLUMN payment_status SET DEFAULT 'pending';

-- 5. Verify the change
SELECT 
    column_name, 
    data_type, 
    column_default
FROM information_schema.columns 
WHERE table_name = 'orders' 
  AND column_name = 'payment_status';

SELECT 'Payment status column type fixed!' as result;
