# Voice Medical Scribe - Setup Instructions

## Overview
The Voice Medical Scribe feature now saves all sessions to your dashboard with full history tracking, including:
- ✅ Voice transcriptions
- ✅ AI-generated clinical notes  
- ✅ Exported PDFs (viewable and downloadable from dashboard)

## Database Setup Required

To enable this feature, you need to run the SQL setup file in your Supabase database.

### Step 1: Access Supabase SQL Editor

1. Go to [https://supabase.com/dashboard](https://supabase.com/dashboard)
2. Select your project: **vpmuooztcqzrrfsvjzwl**
3. Click on **SQL Editor** in the left sidebar

### Step 2: Run the Setup SQL

1. Click **New Query** button
2. Copy the entire contents of `voice_scribe_enhancements.sql`
3. Paste it into the SQL editor
4. Click **Run** or press `Ctrl+Enter`

### Step 3: Verify Table Creation

After running the SQL, verify the table was created:

1. Click on **Table Editor** in left sidebar
2. Look for the new table: `voice_scribe_sessions`
3. You should see columns:
   - `id` (UUID, primary key)
   - `user_id` (UUID, references auth.users)
   - `session_id` (TEXT)
   - `transcription_text` (TEXT)
   - `clinical_notes` (TEXT)
   - `pdf_base64` (TEXT) - stores the PDF
   - `pdf_filename` (TEXT)
   - `created_at` (TIMESTAMPTZ)
   - `updated_at` (TIMESTAMPTZ)
   - `patient_name` (TEXT)
   - `session_duration` (INTEGER)
   - `word_count` (INTEGER)
   - `language` (TEXT)

## How It Works

### Creating a Voice Scribe Session

1. Go to the **Practitioners** page ([nurse.html](nurse.html))
2. Click the **Voice Medical Scribe** button
3. Record your patient consultation
4. Click **Generate Notes** to create AI clinical documentation
5. Click **Export** to save as PDF

### Viewing History in Dashboard

1. Go to your **Dashboard** ([dashboard.html](dashboard.html))
2. Scroll down to **Voice Medical Scribe History** section
3. You'll see all your past sessions with:
   - Date and time of recording
   - Word count
   - Transcription preview
   - AI-generated notes preview
   - PDF viewing and download options

### Features Available

- **View Full**: See complete transcription and clinical notes
- **View PDF**: Open PDF in new browser tab
- **Download PDF**: Download PDF to your device
- **Delete**: Remove session from history (cannot be undone)

## Security & Privacy

- All voice scribe sessions are protected by Row Level Security (RLS)
- You can only view, edit, or delete **your own** sessions
- PDFs are stored as base64-encoded data in the database
- No third parties can access your clinical documentation

## Troubleshooting

### Table Creation Failed

If you get an error running the SQL:

1. Check if table already exists:
   ```sql
   SELECT * FROM voice_scribe_sessions LIMIT 1;
   ```

2. If it exists but has different columns, drop and recreate:
   ```sql
   DROP TABLE IF EXISTS voice_scribe_sessions CASCADE;
   ```
   Then run the `voice_scribe_enhancements.sql` again.

### History Not Loading

1. Check browser console for errors (F12 → Console tab)
2. Verify you're logged in
3. Try the **Refresh** button in the Voice Scribe History section
4. Make sure you've exported at least one PDF from the Voice Scribe

### PDF Not Saving

1. Ensure the SQL table was created successfully
2. Check that you're logged in when exporting
3. Make sure you generated clinical notes before exporting
4. Check browser console for any JavaScript errors

## Benefits

✅ **Complete Clinical Record**: All patient consultations documented and accessible  
✅ **AI-Powered**: Automatically generates structured clinical notes  
✅ **Searchable History**: Find past sessions by date, word count, or content  
✅ **PDF Archive**: Download professional PDFs with Nrome branding  
✅ **Secure & Private**: Your data is protected and only accessible to you  
✅ **HIPAA-Ready**: Proper documentation for medical compliance  

## Next Steps

After setup:
1. Test the feature by creating a sample voice scribe session
2. Export it as PDF
3. Check your dashboard to confirm it appears in history
4. Try viewing, downloading, and deleting the session

---

**Need Help?** Check the browser console (F12) for detailed error messages, or contact support.
