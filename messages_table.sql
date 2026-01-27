-- =====================================================
-- APPOINTMENT MESSAGES TABLE
-- =====================================================
-- This table stores messages between patients and practitioners
-- for confirmed appointments only
CREATE TABLE IF NOT EXISTS appointment_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    appointment_id UUID REFERENCES appointments(id) ON DELETE CASCADE NOT NULL,
    sender_id UUID REFERENCES auth.users(id) NOT NULL,
    sender_name TEXT NOT NULL,
    sender_role TEXT NOT NULL CHECK (sender_role IN ('patient', 'practitioner')),
    message TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    read_at TIMESTAMPTZ,
    is_read BOOLEAN DEFAULT FALSE
);

-- Indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_messages_appointment ON appointment_messages(appointment_id, created_at);
CREATE INDEX IF NOT EXISTS idx_messages_sender ON appointment_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_unread ON appointment_messages(appointment_id, is_read) WHERE is_read = FALSE;

-- Row Level Security
ALTER TABLE appointment_messages ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Allow users to view messages for their appointments" ON appointment_messages;
DROP POLICY IF EXISTS "Allow users to send messages for their appointments" ON appointment_messages;
DROP POLICY IF EXISTS "Allow users to mark their messages as read" ON appointment_messages;
DROP POLICY IF EXISTS "Allow users to delete messages for their appointments" ON appointment_messages;

-- Policy to allow users to view messages for appointments they're involved in
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
                SELECT 1 FROM medical_practitioners 
                WHERE medical_practitioners.id = appointments.practitioner_id 
                AND medical_practitioners.owner_user_id = auth.uid()
            )
        )
    )
);

-- Policy to allow users to send messages for appointments they're involved in
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
                SELECT 1 FROM medical_practitioners 
                WHERE medical_practitioners.id = appointments.practitioner_id 
                AND medical_practitioners.owner_user_id = auth.uid()
            )
        )
    )
);

-- Policy to allow users to mark messages as read
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
                SELECT 1 FROM medical_practitioners 
                WHERE medical_practitioners.id = appointments.practitioner_id 
                AND medical_practitioners.owner_user_id = auth.uid()
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
                SELECT 1 FROM medical_practitioners 
                WHERE medical_practitioners.id = appointments.practitioner_id 
                AND medical_practitioners.owner_user_id = auth.uid()
            )
        )
    )
);

-- Policy to allow users to delete messages for their appointments
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
                SELECT 1 FROM medical_practitioners 
                WHERE medical_practitioners.id = appointments.practitioner_id 
                AND medical_practitioners.owner_user_id = auth.uid()
            )
        )
    )
);
