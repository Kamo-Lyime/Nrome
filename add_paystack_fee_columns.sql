-- Add Paystack fee tracking columns to appointments table
-- This ensures the total amount paid (including processing fees) is stored correctly

-- Add consultation_fee column (base fee set by practitioner, before processing fees)
ALTER TABLE appointments 
ADD COLUMN IF NOT EXISTS consultation_fee NUMERIC(10, 2);

-- Add paystack_fee column to store the processing fee charged
ALTER TABLE appointments 
ADD COLUMN IF NOT EXISTS paystack_fee NUMERIC(10, 2);

-- Add total_amount column to store the complete amount patient paid (consultation_fee + paystack_fee)
ALTER TABLE appointments 
ADD COLUMN IF NOT EXISTS total_amount NUMERIC(10, 2);

-- Add comment to explain the columns
COMMENT ON COLUMN appointments.consultation_fee IS 'Base consultation fee set by practitioner (before processing fees)';
COMMENT ON COLUMN appointments.paystack_fee IS 'Processing fee charged by Paystack (added on top of consultation fee)';
COMMENT ON COLUMN appointments.total_amount IS 'Total amount paid by patient (consultation_fee + paystack_fee)';

-- Update existing records to populate consultation_fee from amount_paid (if amount_paid exists)
-- Then calculate paystack_fee and total_amount
-- This assumes ZAR currency for existing records (1.5% + R1, capped at R50)
UPDATE appointments 
SET 
    consultation_fee = CASE 
        WHEN consultation_fee IS NULL THEN COALESCE(amount_paid, 500)
        ELSE consultation_fee 
    END,
    paystack_fee = CASE 
        WHEN paystack_fee IS NULL THEN 
            LEAST(ROUND(COALESCE(amount_paid, 500) * 0.015) + 1, 50)
        ELSE paystack_fee 
    END,
    total_amount = CASE 
        WHEN total_amount IS NULL THEN 
            COALESCE(amount_paid, 500) + 
            LEAST(ROUND(COALESCE(amount_paid, 500) * 0.015) + 1, 50)
        ELSE total_amount 
    END
WHERE consultation_fee IS NULL OR paystack_fee IS NULL OR total_amount IS NULL;

-- Verify the update
SELECT 
    booking_id,
    practitioner_name,
    consultation_fee,
    paystack_fee,
    total_amount,
    currency,
    ROUND(consultation_fee * 0.8) as practitioner_80_percent,
    ROUND(consultation_fee * 0.2) as platform_20_percent,
    amount_paid as old_amount_paid_field
FROM appointments 
ORDER BY created_at DESC 
LIMIT 10;

-- Example output for verification:
-- booking_id | practitioner_name | consultation_fee | paystack_fee | total_amount | currency | practitioner_80% | platform_20%
-- -----------|-------------------|------------------|--------------|--------------|----------|------------------|-------------
-- APT001     | Dr. Smith         | 500              | 9            | 509          | ZAR      | 400              | 100
-- APT002     | Dr. Johnson       | 3455             | 53           | 3508         | ZAR      | 2764             | 691
-- APT003     | Dr. Williams      | 1000             | 16           | 1016         | NGN      | 800              | 200

/*
PAYSTACK FEE CALCULATION LOGIC:
================================

The system adds Paystack processing fees ON TOP of the consultation fee.
The 80/20 split applies ONLY to the consultation fee, NOT the processing fee.

Fee Structure by Currency:
--------------------------
ZAR (South Africa):     1.5% + R1 (capped at R50)
NGN (Nigeria):          1.5% + ₦100 (capped at ₦2000)
KES (Kenya):            1.5% + KSh5
GHS (Ghana):            1.95%
USD/EUR/Others:         3.9% + $0.10

Example Calculation (ZAR 3455):
-------------------------------
1. Consultation Fee: 3455 ZAR
   - Practitioner (80%): 2764 ZAR
   - Platform (20%): 691 ZAR

2. Paystack Fee: (3455 * 0.015) + 1 = 52.825 → 53 ZAR (rounded, capped at 50)
   - Actual: 52 ZAR (after cap check: min(53, 50) = 50, but before rounding = 52)

3. Total Patient Pays: 3455 + 52 = 3507 ZAR

Payment Distribution:
--------------------
Patient pays:        3507 ZAR
├─ Consultation:     3455 ZAR
│  ├─ Practitioner:  2764 ZAR (80%)
│  └─ Platform:       691 ZAR (20%)
└─ Processing:         52 ZAR (to Paystack)

UX Display Messages:
-------------------
"Total: 3507 ZAR (includes processing fees)"
"Consultation: 3455 ZAR (2764 to practitioner + 691 platform)"
"Processing: 52 ZAR"
"ℹ️ The total amount includes secure payment processing and platform service fees."

Refund Policy:
--------------
- Cancel ≥24h before: Full refund of 3507 ZAR (consultation + processing)
- Cancel <24h before: No refund
- No-show: No refund
- Practitioner cancels: Full refund of 3507 ZAR
- Not confirmed in 24h: Full refund of 3507 ZAR
*/
