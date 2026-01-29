-- Fix RLS policies for appointment_logs and payment_transactions
-- This is needed for triggers and system inserts during payment processing

-- =====================================================
-- 1. FIX APPOINTMENT_LOGS POLICIES
-- =====================================================

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users view logs for their appointments" ON appointment_logs;
DROP POLICY IF EXISTS "Allow insert logs for appointments" ON appointment_logs;

-- Policy: Allow reading logs for appointments user has access to
CREATE POLICY "Users view logs for their appointments"
ON appointment_logs
FOR SELECT
USING (
    appointment_id IN (
        SELECT id FROM appointments WHERE user_id = auth.uid()
    ) OR
    appointment_id IN (
        SELECT a.id FROM appointments a
        JOIN medical_practitioners mp ON a.practitioner_id = mp.id
        WHERE mp.owner_user_id = auth.uid()
    )
);

-- Policy: Allow inserting logs (for triggers and system operations)
CREATE POLICY "Allow insert logs for appointments"
ON appointment_logs
FOR INSERT
WITH CHECK (true);  -- Allow inserts from triggers/system

-- =====================================================
-- 2. FIX PAYMENT_TRANSACTIONS POLICIES
-- =====================================================

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users view own transactions" ON payment_transactions;
DROP POLICY IF EXISTS "Practitioners view their transactions" ON payment_transactions;
DROP POLICY IF EXISTS "Allow insert transactions" ON payment_transactions;

-- Policy: Users can view their own transactions
CREATE POLICY "Users view own transactions"
ON payment_transactions
FOR SELECT
USING (auth.uid() = patient_id);

-- Policy: Practitioners can view transactions for their appointments
CREATE POLICY "Practitioners view their transactions"
ON payment_transactions
FOR SELECT
USING (
    practitioner_id IN (
        SELECT id FROM medical_practitioners WHERE owner_user_id = auth.uid()
    )
);

-- Policy: Allow inserting transactions (for payment processing)
CREATE POLICY "Allow insert transactions"
ON payment_transactions
FOR INSERT
WITH CHECK (true);  -- Allow inserts from payment system

-- =====================================================
-- 3. VERIFY POLICIES
-- =====================================================

-- Verify appointment_logs policies
SELECT 'appointment_logs policies:' as table_name;
SELECT schemaname, tablename, policyname, permissive, roles, cmd 
FROM pg_policies 
WHERE tablename = 'appointment_logs';

-- Verify payment_transactions policies
SELECT 'payment_transactions policies:' as table_name;
SELECT schemaname, tablename, policyname, permissive, roles, cmd 
FROM pg_policies 
WHERE tablename = 'payment_transactions';
