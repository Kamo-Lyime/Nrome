-- Voice Medical Scribe Enhancements
-- Adds PDF storage and comprehensive session tracking

-- Create table for storing voice scribe sessions with PDFs
CREATE TABLE IF NOT EXISTS voice_scribe_sessions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    session_id TEXT NOT NULL,
    transcription_text TEXT,
    clinical_notes TEXT,
    pdf_base64 TEXT, -- Base64 encoded PDF
    pdf_filename TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    patient_name TEXT,
    session_duration INTEGER, -- in seconds
    word_count INTEGER,
    language TEXT DEFAULT 'en-US'
);

-- Create indices for faster queries
CREATE INDEX IF NOT EXISTS idx_voice_scribe_sessions_user 
ON voice_scribe_sessions(user_id);

CREATE INDEX IF NOT EXISTS idx_voice_scribe_sessions_created 
ON voice_scribe_sessions(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_voice_scribe_sessions_session_id 
ON voice_scribe_sessions(session_id);

-- Enable Row Level Security
ALTER TABLE voice_scribe_sessions ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own voice scribe sessions
CREATE POLICY "Users can view their own voice scribe sessions"
ON voice_scribe_sessions
FOR SELECT
USING (auth.uid() = user_id);

-- Policy: Users can insert their own voice scribe sessions
CREATE POLICY "Users can insert their own voice scribe sessions"
ON voice_scribe_sessions
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own voice scribe sessions
CREATE POLICY "Users can update their own voice scribe sessions"
ON voice_scribe_sessions
FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can delete their own voice scribe sessions
CREATE POLICY "Users can delete their own voice scribe sessions"
ON voice_scribe_sessions
FOR DELETE
USING (auth.uid() = user_id);

-- Add comments for documentation
COMMENT ON TABLE voice_scribe_sessions IS 'Stores voice medical scribe sessions with transcriptions, clinical notes, and exported PDFs';
COMMENT ON COLUMN voice_scribe_sessions.transcription_text IS 'Raw voice-to-text transcription';
COMMENT ON COLUMN voice_scribe_sessions.clinical_notes IS 'AI-generated clinical documentation (Chief Complaint, HPI, Assessment, Plan)';
COMMENT ON COLUMN voice_scribe_sessions.pdf_base64 IS 'Base64 encoded PDF export of clinical documentation';
COMMENT ON COLUMN voice_scribe_sessions.session_duration IS 'Recording duration in seconds';
COMMENT ON COLUMN voice_scribe_sessions.word_count IS 'Number of words in transcription';
