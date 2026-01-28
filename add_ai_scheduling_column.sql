-- Add AI scheduling suggestion column to appointments table
-- This stores the AI-generated scheduling recommendation shown during booking

ALTER TABLE appointments 
ADD COLUMN IF NOT EXISTS ai_scheduling_suggestion TEXT;

-- Add comment for documentation
COMMENT ON COLUMN appointments.ai_scheduling_suggestion IS 'AI-generated scheduling recommendation based on patient symptoms and appointment details';

-- Create index for appointments with AI suggestions
CREATE INDEX IF NOT EXISTS idx_appointments_ai_suggestion 
ON appointments(ai_scheduling_suggestion) 
WHERE ai_scheduling_suggestion IS NOT NULL;
