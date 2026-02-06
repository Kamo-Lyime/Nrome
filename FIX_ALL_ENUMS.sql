-- COMPLETE FIX: Convert all enum columns to VARCHAR for flexibility
-- Run this in Supabase SQL Editor

-- 1. First, let's see what enum values currently exist
SELECT 
    t.typname AS enum_name,
    array_agg(e.enumlabel ORDER BY e.enumsortorder) AS allowed_values
FROM pg_type t 
JOIN pg_enum e ON t.oid = e.enumtypid  
WHERE t.typname IN ('order_status', 'payment_status', 'order_status_enum', 'payment_status_enum')
GROUP BY t.typname;

-- 2. Drop ALL views that depend on orders table
DROP VIEW IF EXISTS pharmacy_order_view CASCADE;
DROP VIEW IF EXISTS patient_order_tracking CASCADE;
DROP VIEW IF EXISTS order_summary CASCADE;
DROP VIEW IF EXISTS pharmacy_dashboard_stats CASCADE;

-- 3. Drop triggers that depend on status column
DROP TRIGGER IF EXISTS enforce_order_status_transition ON orders;
DROP TRIGGER IF EXISTS validate_payment_status ON orders;
DROP TRIGGER IF EXISTS order_status_notification ON orders;

-- 4. Drop ALL policies on orders table (we'll recreate basic ones after)
DROP POLICY IF EXISTS orders_update_patient ON orders;
DROP POLICY IF EXISTS orders_select_patient ON orders;
DROP POLICY IF EXISTS orders_insert_patient ON orders;
DROP POLICY IF EXISTS orders_pharmacy_view ON orders;
DROP POLICY IF EXISTS orders_pharmacy_update ON orders;

-- 5. Convert status column from enum to VARCHAR
DO $$ 
BEGIN
    -- Check if status column exists and is enum type
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'orders' 
        AND column_name = 'status'
    ) THEN
        -- Change from enum to VARCHAR
        ALTER TABLE orders 
        ALTER COLUMN status TYPE VARCHAR(50) 
        USING status::text;
        
        ALTER TABLE orders 
        ALTER COLUMN status SET DEFAULT 'created';
        
        RAISE NOTICE 'Changed status from enum to VARCHAR';
    END IF;
END $$;

-- 5. Convert payment_status column from enum to VARCHAR
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'orders' 
        AND column_name = 'payment_status'
    ) THEN
        -- Change from enum to VARCHAR
        ALTER TABLE orders 
        ALTER COLUMN payment_status TYPE VARCHAR(50) 
        USING payment_status::text;
        
        ALTER TABLE orders 
        ALTER COLUMN payment_status SET DEFAULT 'pending';
        
        RAISE NOTICE 'Changed payment_status from enum to VARCHAR';
    END IF;
END $$;

-- 5. Add payment_reference if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'orders' 
        AND column_name = 'payment_reference'
    ) THEN
        ALTER TABLE orders ADD COLUMN payment_reference VARCHAR(100);
        RAISE NOTICE 'Added payment_reference column';
    END IF;
END $$;

-- 6. Recreate the views (if they were used)
CREATE OR REPLACE VIEW pharmacy_order_view AS
SELECT 
    o.*,
    p.name as pharmacy_name,
    p.phone as pharmacy_phone
FROM orders o
LEFT JOIN pharmacies p ON o.pharmacy_id = p.id;

CREATE OR REPLACE VIEW patient_order_tracking AS
SELECT 
    o.id,
    o.order_number,
    o.status,
    o.payment_status,
    o.payment_reference,
    o.total_amount,
    o.delivery_address,
    o.created_at,
    p.name as pharmacy_name
FROM orders o
LEFT JOIN pharmacies p ON o.pharmacy_id = p.id;

-- 7. Verify all columns
SELECT 
    column_name, 
    data_type,
    column_default,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'orders' 
  AND column_name IN ('status', 'payment_status', 'payment_reference')
ORDER BY column_name;

-- 8. Update any orders with old enum values to new standard values
UPDATE orders SET status = 'created' WHERE status NOT IN ('created', 'pending_confirmation', 'confirmed', 'processing', 'ready_for_delivery', 'out_for_delivery', 'delivered', 'cancelled', 'rx_uploaded');
UPDATE orders SET payment_status = 'pending' WHERE payment_status NOT IN ('pending', 'paid', 'failed', 'refunded');

-- 9. Recreate basic RLS policies (since we dropped them)
-- Note: RLS is currently DISABLED in disable_pharmacy_rls_temp.sql, but recreating for when you re-enable
CREATE POLICY "Patients can view own orders"
ON orders FOR SELECT
USING (auth.uid() = patient_id);

CREATE POLICY "Patients can insert own orders"
ON orders FOR INSERT
WITH CHECK (auth.uid() = patient_id);

CREATE POLICY "Patients can update own orders"
ON orders FOR UPDATE
USING (auth.uid() = patient_id);

SELECT 'Enum columns converted to VARCHAR successfully!' as result;
