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
