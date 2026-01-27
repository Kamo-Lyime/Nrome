-- Update triage_assessments table to include AI assessment text
ALTER TABLE triage_assessments 
ADD COLUMN IF NOT EXISTS ai_assessment TEXT;

-- Optional: Add index for faster queries by date
CREATE INDEX IF NOT EXISTS idx_triage_created_at ON triage_assessments(created_at DESC);

-- Optional: Add index for urgency level queries
CREATE INDEX IF NOT EXISTS idx_triage_urgency ON triage_assessments(urgency_level);
