-- =====================================================
-- FIX APPOINTMENTS TABLE VARCHAR CONSTRAINTS
-- =====================================================
-- The error "value too long for type character varying(20)" means
-- some column is too small for the data being inserted
-- ERROR: cannot alter type of a column used by a view or rule
-- SOLUTION: Drop views, alter columns, recreate views

-- =====================================================
-- STEP 1: Drop views that depend on appointments columns
-- =====================================================

DROP VIEW IF EXISTS pending_confirmations CASCADE;
DROP VIEW IF EXISTS overdue_confirmations CASCADE;
DROP VIEW IF EXISTS upcoming_appointments CASCADE;

-- =====================================================
-- STEP 1B: Drop RLS policies that depend on appointments columns
-- =====================================================

DROP POLICY IF EXISTS "Allow users to view messages for their appointments" ON appointment_messages;
DROP POLICY IF EXISTS "Allow users to send messages for their appointments" ON appointment_messages;
DROP POLICY IF EXISTS "Allow users to mark their messages as read" ON appointment_messages;
DROP POLICY IF EXISTS "Allow users to delete messages for their appointments" ON appointment_messages;

-- =====================================================
-- STEP 2: Expand VARCHAR fields that are too small
-- =====================================================

-- Expand booking_id (APT-006235 is only 10 chars but need room for growth)
ALTER TABLE appointments 
    ALTER COLUMN booking_id TYPE VARCHAR(50);

-- Expand status (statuses like 'PENDING_PRACTITIONER_ACCEPTANCE' are >20 chars)
ALTER TABLE appointments 
    ALTER COLUMN status TYPE VARCHAR(100);

-- Expand appointment_type if it exists
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'appointments' 
        AND column_name = 'appointment_type'
        AND character_maximum_length = 20
    ) THEN
        ALTER TABLE appointments ALTER COLUMN appointment_type TYPE VARCHAR(100);
    END IF;
END $$;

-- Expand payment_status if it exists
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'appointments' 
        AND column_name = 'payment_status'
        AND character_maximum_length = 20
    ) THEN
        ALTER TABLE appointments ALTER COLUMN payment_status TYPE VARCHAR(50);
    END IF;
END $$;

-- =====================================================
-- STEP 3: Recreate views with correct table references
-- =====================================================

-- View: Pending confirmations (need practitioner action)
-- UPDATED to use 'practitioners' table instead of 'medical_practitioners'
CREATE OR REPLACE VIEW pending_confirmations AS
SELECT 
    a.id,
    a.booking_id,
    a.patient_name,
    a.appointment_date,
    a.appointment_time,
    a.amount_paid,
    a.confirmation_deadline,
    p.full_name as practitioner_name,
    p.email_address as practitioner_email
FROM appointments a
JOIN practitioners p ON a.practitioner_id = p.id
WHERE a.status = 'PENDING_CONFIRMATION'
AND a.confirmation_deadline > NOW()
ORDER BY a.confirmation_deadline ASC;

-- View: Overdue confirmations (need auto-refund)
CREATE OR REPLACE VIEW overdue_confirmations AS
SELECT 
    a.id,
    a.booking_id,
    a.payment_reference,
    a.amount_paid,
    a.confirmation_deadline,
    a.patient_email
FROM appointments a
WHERE a.status = 'PENDING_CONFIRMATION'
AND a.confirmation_deadline <= NOW()
ORDER BY a.confirmation_deadline ASC;

-- View: Upcoming appointments
-- UPDATED to use 'practitioners' table instead of 'medical_practitioners'
CREATE OR REPLACE VIEW upcoming_appointments AS
SELECT 
    a.id,
    a.booking_id,
    a.patient_name,
    a.appointment_date,
    a.appointment_time,
    a.status,
    a.no_show_checked,
    p.full_name as practitioner_name
FROM appointments a
JOIN practitioners p ON a.practitioner_id = p.id
WHERE a.status = 'CONFIRMED'
AND a.appointment_date >= CURRENT_DATE
ORDER BY a.appointment_date ASC, a.appointment_time ASC;

-- =====================================================
-- STEP 3B: Recreate RLS policies with correct table references
-- =====================================================

-- Policy to allow users to view messages for appointments they're involved in
-- UPDATED to use 'practitioners' table instead of 'medical_practitioners'
CREATE POLICY "Allow users to view messages for their appointments" ON appointment_messages
FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM appointments
        WHERE appointments.id = appointment_messages.appointment_id
        AND (
            appointments.user_id = auth.uid() 
            OR 
            EXISTS (
                SELECT 1 FROM practitioners 
                WHERE practitioners.id = appointments.practitioner_id 
                AND practitioners.user_id = auth.uid()
            )
        )
    )
);

-- Policy to allow users to send messages for appointments they're involved in
-- UPDATED to use 'practitioners' table instead of 'medical_practitioners'
CREATE POLICY "Allow users to send messages for their appointments" ON appointment_messages
FOR INSERT
WITH CHECK (
    sender_id = auth.uid() AND
    EXISTS (
        SELECT 1 FROM appointments
        WHERE appointments.id = appointment_messages.appointment_id
        AND appointments.status = 'confirmed'
        AND (
            appointments.user_id = auth.uid() 
            OR 
            EXISTS (
                SELECT 1 FROM practitioners 
                WHERE practitioners.id = appointments.practitioner_id 
                AND practitioners.user_id = auth.uid()
            )
        )
    )
);

-- Policy to allow users to mark messages as read
-- UPDATED to use 'practitioners' table instead of 'medical_practitioners'
CREATE POLICY "Allow users to mark their messages as read" ON appointment_messages
FOR UPDATE
USING (
    EXISTS (
        SELECT 1 FROM appointments
        WHERE appointments.id = appointment_messages.appointment_id
        AND (
            appointments.user_id = auth.uid() 
            OR 
            EXISTS (
                SELECT 1 FROM practitioners 
                WHERE practitioners.id = appointments.practitioner_id 
                AND practitioners.user_id = auth.uid()
            )
        )
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM appointments
        WHERE appointments.id = appointment_messages.appointment_id
        AND (
            appointments.user_id = auth.uid() 
            OR 
            EXISTS (
                SELECT 1 FROM practitioners 
                WHERE practitioners.id = appointments.practitioner_id 
                AND practitioners.user_id = auth.uid()
            )
        )
    )
);

-- Policy to allow users to delete messages for their appointments
-- UPDATED to use 'practitioners' table instead of 'medical_practitioners'
CREATE POLICY "Allow users to delete messages for their appointments" ON appointment_messages
FOR DELETE
USING (
    EXISTS (
        SELECT 1 FROM appointments
        WHERE appointments.id = appointment_messages.appointment_id
        AND (
            appointments.user_id = auth.uid() 
            OR 
            EXISTS (
                SELECT 1 FROM practitioners 
                WHERE practitioners.id = appointments.practitioner_id 
                AND practitioners.user_id = auth.uid()
            )
        )
    )
);

-- =====================================================
-- STEP 4: Verify the changes
-- =====================================================

SELECT 
    column_name,
    data_type,
    character_maximum_length,
    CASE 
        WHEN character_maximum_length >= 50 THEN '✅ Fixed'
        ELSE '❌ Still too small'
    END as status
FROM information_schema.columns
WHERE table_name = 'appointments'
    AND data_type = 'character varying'
ORDER BY column_name;

-- Verify views were recreated
SELECT 
    table_name as view_name,
    '✅ Recreated' as status
FROM information_schema.views
WHERE table_name IN ('pending_confirmations', 'overdue_confirmations', 'upcoming_appointments');

-- =====================================================
-- COMPLETE! ✅
-- =====================================================
-- ✅ Dropped 3 dependent views (pending_confirmations, overdue_confirmations, upcoming_appointments)
-- ✅ Dropped 4 RLS policies on appointment_messages table
-- ✅ Expanded VARCHAR columns (20 → 50-100)
-- ✅ Recreated all 3 views with 'practitioners' table reference
-- ✅ Recreated all 4 RLS policies with 'practitioners' table reference (using user_id instead of owner_user_id)
-- 
-- Now appointments should save to Supabase without VARCHAR errors!
-- Refresh nurse.html and try booking again
-- =====================================================
