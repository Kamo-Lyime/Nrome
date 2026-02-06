-- URGENT FIX: Add payment columns and verify orders table
-- Run this in Supabase SQL Editor NOW

-- 1. Check if columns exist
DO $$ 
BEGIN
    -- Add payment_status if missing
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'orders' AND column_name = 'payment_status') THEN
        ALTER TABLE orders ADD COLUMN payment_status VARCHAR(50) DEFAULT 'pending';
        RAISE NOTICE 'Added payment_status column';
    ELSE
        RAISE NOTICE 'payment_status column already exists';
    END IF;

    -- Add payment_reference if missing
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'orders' AND column_name = 'payment_reference') THEN
        ALTER TABLE orders ADD COLUMN payment_reference VARCHAR(100);
        RAISE NOTICE 'Added payment_reference column';
    ELSE
        RAISE NOTICE 'payment_reference column already exists';
    END IF;

    -- Add paystack_fee if missing
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'orders' AND column_name = 'paystack_fee') THEN
        ALTER TABLE orders ADD COLUMN paystack_fee DECIMAL(10,2) DEFAULT 0;
        RAISE NOTICE 'Added paystack_fee column';
    ELSE
        RAISE NOTICE 'paystack_fee column already exists';
    END IF;

    -- Add platform_fee if missing
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'orders' AND column_name = 'platform_fee') THEN
        ALTER TABLE orders ADD COLUMN platform_fee DECIMAL(10,2) DEFAULT 0;
        RAISE NOTICE 'Added platform_fee column';
    ELSE
        RAISE NOTICE 'platform_fee column already exists';
    END IF;

    -- Add pharmacy_amount if missing
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'orders' AND column_name = 'pharmacy_amount') THEN
        ALTER TABLE orders ADD COLUMN pharmacy_amount DECIMAL(10,2) DEFAULT 0;
        RAISE NOTICE 'Added pharmacy_amount column';
    ELSE
        RAISE NOTICE 'pharmacy_amount column already exists';
    END IF;
END $$;

-- 2. Update existing orders with 'pending' payment_status to have correct fees
UPDATE orders 
SET 
    platform_fee = ROUND(subtotal * 0.10, 2),
    pharmacy_amount = ROUND(subtotal + delivery_fee - (subtotal * 0.10), 2),
    paystack_fee = ROUND(((subtotal + delivery_fee) * 0.015) + 2.00, 2)
WHERE payment_status = 'pending' 
  AND (platform_fee = 0 OR platform_fee IS NULL);

-- 3. Check for orders that were paid via Paystack but still show as pending
-- This will show you if any orders need manual fixing
SELECT 
    id,
    order_number,
    payment_status,
    payment_reference,
    total_amount,
    created_at
FROM orders 
WHERE payment_status = 'pending' 
  AND created_at > NOW() - INTERVAL '2 hours'
ORDER BY created_at DESC;

-- 4. MANUAL FIX: If you see an order that should be paid, update it:
-- Replace 'ORDER_NUMBER_HERE' with the actual order number from your recent test
/*
UPDATE orders 
SET 
    payment_status = 'paid',
    status = 'pending_confirmation',
    updated_at = NOW()
WHERE order_number = 'NRM-1770335959622';  -- Replace with your order number
*/

SELECT 'Payment columns added/verified. Check the SELECT query results above.' as result;
