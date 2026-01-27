-- Add clinical_notes column to voice_transcriptions table
-- This column stores AI-generated clinical documentation from voice transcriptions

ALTER TABLE voice_transcriptions 
ADD COLUMN IF NOT EXISTS clinical_notes TEXT,
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Add index for faster session_id lookups
CREATE INDEX IF NOT EXISTS idx_voice_transcriptions_session_id 
ON voice_transcriptions(session_id);

-- Comment for documentation
COMMENT ON COLUMN voice_transcriptions.clinical_notes IS 'AI-generated clinical documentation including Chief Complaint, HPI, Assessment, and Plan';
