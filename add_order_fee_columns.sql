-- Add fee columns to orders table if they don't exist
-- Run this in Supabase SQL Editor

-- Check and add paystack_fee column
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'orders' AND column_name = 'paystack_fee') THEN
        ALTER TABLE orders ADD COLUMN paystack_fee DECIMAL(10,2) DEFAULT 0;
    END IF;
END $$;

-- Check and add platform_fee column
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'orders' AND column_name = 'platform_fee') THEN
        ALTER TABLE orders ADD COLUMN platform_fee DECIMAL(10,2) DEFAULT 0;
    END IF;
END $$;

-- Check and add pharmacy_amount column
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'orders' AND column_name = 'pharmacy_amount') THEN
        ALTER TABLE orders ADD COLUMN pharmacy_amount DECIMAL(10,2) DEFAULT 0;
    END IF;
END $$;

-- Check and add payment_status column
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'orders' AND column_name = 'payment_status') THEN
        ALTER TABLE orders ADD COLUMN payment_status VARCHAR(50) DEFAULT 'pending';
    END IF;
END $$;

-- Check and add payment_reference column
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'orders' AND column_name = 'payment_reference') THEN
        ALTER TABLE orders ADD COLUMN payment_reference VARCHAR(100);
    END IF;
END $$;

-- Update existing orders to calculate fees retroactively
UPDATE orders 
SET 
    platform_fee = ROUND(subtotal * 0.10, 2),
    pharmacy_amount = ROUND(subtotal - (subtotal * 0.10), 2),
    paystack_fee = ROUND(((subtotal + delivery_fee) * 0.015) + 2.00, 2)
WHERE platform_fee = 0 OR platform_fee IS NULL;

SELECT 'Fee columns added/updated successfully!' as result;
