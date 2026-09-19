# Practitioner Registration - Integrated into nurse.html

## Overview
The comprehensive 15-phase practitioner verification system is now **fully integrated** into the nurse.html page. Practitioners can register directly from the "Register Your Medical Practice" collapsible form, which uses a 3-step wizard interface with document upload and verification workflow.

## Why Integrated into nurse.html?
The AI appointment booking system works with **nurse.html** and recommends practitioners from the **"All Available Registered Medical Practitioners"** listings on that page. By integrating the registration wizard into nurse.html, practitioners can:
1. Register on the same page used by AI for recommendations
2. Have their profiles immediately available for patient bookings
3. Undergo verification without leaving the platform

## 3-Step Registration Wizard

### Step 1: Profile Information
**Required Fields:**
- Full Name (as it appears on registration certificate)
- Profession (dropdown: Medical Practitioner, Nurse, Specialist, etc.)
- Registration Number (HPCSA or SANC)
- Practice Address (hidden from patients, used by AI for location matching)
- Medical Scheme Billing Support (Yes/No)

**Optional Fields:**
- Practice Number (BHF number)
- Specialty (e.g., General Practice, Cardiology)
- Practice Name (e.g., Smith Medical Centre)

**What Happens:**
- Form validation ensures all required fields are filled
- Data is stored temporarily in `practitionerProfileData` object
- "Next" button navigates to Step 2

### Step 2: Upload Documents
**Required Documents (all mandatory):**
1. **ID Document** - South African ID or Passport (PDF/JPG/PNG, max 5MB)
2. **Registration Certificate** - HPCSA or SANC certificate
3. **Degree Certificate** - Medical degree or nursing qualification
4. **Proof of Address** - Recent utility bill or bank statement (not older than 3 months)

**Features:**
- Drag-and-drop file upload
- Click to browse file selection
- Real-time file validation (size, type)
- Visual preview of uploaded files
- Remove/replace document capability
- Upload areas turn green when file is uploaded

**What Happens:**
- Files are validated for type (PDF, JPG, PNG) and size (max 5MB)
- Files are stored temporarily in `uploadedDocuments` object
- Cannot proceed to Step 3 without all 4 documents
- "Next" button navigates to Step 3

### Step 3: Review & Submit
**Review Summary Shows:**
- All profile information from Step 1
- List of uploaded documents with file names
- What happens next explanation (verification process)

**Submission Process:**
When practitioner clicks "Submit for Verification":

1. **Documents Upload to Supabase Storage:**
   - Files are uploaded to `verification-documents` bucket
   - File naming: `{userId}_{documentType}_{timestamp}_{originalName}`
   - Public URLs are generated for each document

2. **Practitioner Record Created:**
   - Data saved to `practitioners` table
   - Initial status: `pending_documents`
   - Includes all profile information from Step 1

3. **Document Records Created:**
   - Each document saved to `practitioner_documents` table
   - Links document URL to practitioner ID
   - Records file name, size, upload timestamp

4. **Verification Request Created:**
   - Entry created in `verification_requests` table
   - Status: `pending_review`
   - Submitted timestamp recorded

5. **Success Message Displayed:**
   - Shows confirmation of submission
   - Displays submission date/time
   - Explains next steps (admin review, 2-3 business days)

## Database Tables Used

### `practitioners`
Stores practitioner profile information:
- `user_id` - Links to Supabase Auth user
- `full_name`, `profession`, `registration_number`
- `practice_number`, `specialty`, `practice_name`
- `address` (hidden from public, used by AI)
- `medical_scheme_billing_supported`
- `verification_status` (pending_documents, pending_review, verified, etc.)

### `practitioner_documents`
Stores document metadata:
- `practitioner_id` - Foreign key to practitioners
- `document_type` (id_document, registration_certificate, etc.)
- `file_url` - Supabase Storage public URL
- `file_name`, `file_size`, `uploaded_at`

### `verification_requests`
Tracks verification workflow:
- `practitioner_id` - Foreign key to practitioners
- `status` (pending_review, under_review, verified, rejected, expired)
- `submitted_at`, `reviewed_at`, `reviewer_notes`

## JavaScript Functions

### Step Navigation
```javascript
goToRegistrationStep(stepNumber)
```
- Validates current step before allowing forward navigation
- Updates step indicator (active/completed states)
- Shows/hides step content divs
- Populates review summary on Step 3

### Document Upload
```javascript
triggerFileUpload(docType)
handleFileSelect(event, docType)
removeDocument(docType)
```
- Handles click-to-upload and drag-and-drop
- Validates file size (5MB max) and type (PDF, JPG, PNG)
- Stores files in `uploadedDocuments` object
- Shows preview with file name and size
- Allows removal and replacement

### Form Submission
```javascript
// Step 1
document.getElementById('profileForm').addEventListener('submit', ...)
validateProfileForm()

// Final Submission
submitPractitionerApplication()
```
- Validates required fields
- Uploads documents to Supabase Storage
- Creates database records
- Shows success/error messages

### Form Reset
```javascript
closeRegistrationForm()
```
- Resets wizard to Step 1
- Clears all form fields
- Removes uploaded documents
- Hides success message

## User Flow

1. **Patient/Practitioner lands on nurse.html**
2. **Clicks "Register Your Medical Practice"** button
3. **Form expands** (collapsible div)
4. **Step 1 visible** - Fills in profile information, clicks "Next: Upload Documents"
5. **Step 2 visible** - Uploads 4 required documents, clicks "Next: Review & Submit"
6. **Step 3 visible** - Reviews summary, clicks "Submit for Verification"
7. **Submission processing** - Documents uploaded, records created
8. **Success message shown** - Application submitted, explains next steps
9. **Click "Close"** - Form collapses, wizard resets to Step 1

## Admin Review Process

After practitioner submits:

1. **Admin logs into admin-pharmacy-review.html**
2. **Clicks "Practitioners" tab** (dual-tab interface)
3. **Sees pending applications** in table
4. **Clicks "Review"** to open modal with:
   - All profile information
   - Clickable document links (view in new tab)
   - Trust score (calculated automatically)
   - AI verification confidence (if AI extraction ran)
5. **Admin can:**
   - **Approve** - Sets status to `verified`, practitioner can receive bookings
   - **Reject** - Sets status to `rejected`, adds reviewer notes
   - **Request More Info** - Sets status to `pending_documents`, sends notification

## AI Document Extraction (Background)

After documents are uploaded, an **xAI/Grok Vision API** process can analyze:

1. **Extract text** from uploaded documents
2. **Validate** registration number matches certificate
3. **Check** name consistency across documents
4. **Detect discrepancies** (e.g., ID name ≠ certificate name)
5. **Calculate confidence score** (0-100%)
6. **Store results** in `ai_document_extractions` table

This helps admin reviewers by:
- Highlighting potential issues
- Auto-completing verification checks
- Improving review speed

## Trust Score Calculation

Automatically calculated when practitioner record is created:

**Total: 100 Points**
- **Name Match** (10 pts) - Name consistent across documents
- **All Documents** (10 pts) - All 4 documents uploaded
- **ID Verified** (20 pts) - Valid SA ID or passport
- **Registration Verified** (40 pts) - HPCSA/SANC check passed
- **Practice Number** (20 pts) - Valid BHF practice number

Trust score displayed in:
- Admin review dashboard
- Public practitioner listings (if verified)
- Patient booking interface

## Automated Workflows

### Reminder System (pg_cron)
- **7-day incomplete reminder** - If status still `draft` or `pending_documents`
- **30-day expiry warning** - If verification expires in 30 days

### Auto-Expiry
- **12-month reverification** - All verifications expire after 12 months
- Status changes to `expired`
- Practitioner notified to re-upload documents

### Notifications
- Email sent on status changes:
  - `verified` - "Congratulations! You're verified"
  - `rejected` - "Application rejected, reason: ..."
  - `pending_documents` - "Please upload missing documents"

## Integration with AI Appointment Booking

Once practitioner is **verified**:

1. **Profile appears** in "All Available Registered Medical Practitioners" section
2. **AI chatbot can recommend** practitioner based on:
   - Patient location vs. practice address
   - Specialty vs. patient symptoms
   - Medical scheme billing support
   - Availability
3. **Patients can book** appointments directly
4. **Verification badge** displayed next to name

## Key Differences from Standalone practitioner-register.html

| Feature | Standalone | Integrated into nurse.html |
|---------|-----------|---------------------------|
| **Location** | Separate page | Collapsible section in nurse.html |
| **Access** | Direct URL navigation | "Register Your Medical Practice" button |
| **UI Container** | Full page layout | Card in collapsible div |
| **Form Toggle** | N/A (always visible) | openRegistrationForm/closeRegistrationForm |
| **Reset Behavior** | Page reload | goToRegistrationStep(1) + form reset |
| **Integration** | Standalone | Works with AI booking on same page |

## Files Modified

### nurse.html
**Added:**
- Step indicator styles (CSS)
- Document upload area styles
- Drag-and-drop styles
- 3-step wizard HTML (replaced old simple form)
- Step navigation functions
- Document upload handlers
- Final submission logic
- Form reset logic

**Removed:**
- Old `serviceForm` with basic practitioner fields
- Old submit handler that saved to `medical_practitioners` table

### Unchanged Files
- practitioner_verification_schema.sql (database tables)
- practitioner_verification_rls.sql (security policies)
- ai_document_extraction.sql (AI functions)
- reminder_reverification_system.sql (automated workflows)
- verification_badge_display.sql (public search)
- admin-pharmacy-review.html (admin dashboard)
- All documentation files (.md)

## Testing Checklist

- [ ] Click "Register Your Medical Practice" button
- [ ] Form expands correctly
- [ ] Step 1: Fill all required fields
- [ ] Step 1: Validation works for missing fields
- [ ] Step 1: Can't proceed without medical scheme billing selection
- [ ] Step 1: Click "Next" navigates to Step 2
- [ ] Step 2: All 4 document upload areas visible
- [ ] Step 2: Click to upload file works
- [ ] Step 2: Drag-and-drop file works
- [ ] Step 2: File validation (5MB max, PDF/JPG/PNG only)
- [ ] Step 2: File preview shows file name and size
- [ ] Step 2: Remove document button works
- [ ] Step 2: Can't proceed without all 4 documents
- [ ] Step 2: Click "Back" returns to Step 1
- [ ] Step 2: Click "Next" navigates to Step 3
- [ ] Step 3: Review summary shows all profile data
- [ ] Step 3: Review summary shows all uploaded documents
- [ ] Step 3: Click "Back" returns to Step 2
- [ ] Step 3: Click "Submit for Verification" uploads documents
- [ ] Step 3: Submission creates practitioner record
- [ ] Step 3: Submission creates document records
- [ ] Step 3: Submission creates verification request
- [ ] Success message displays after submission
- [ ] Click "Close" resets wizard to Step 1
- [ ] Click "Close" collapses form
- [ ] Form can be reopened and used again

## Troubleshooting

**Error: "Supabase client not configured"**
- Check `config.js` has valid Supabase URL and anon key
- Ensure config.js is loaded before nurse.html scripts

**Error: "Failed to upload {document type}"**
- Check Supabase Storage bucket `verification-documents` exists
- Verify bucket has public access policy
- Check file size < 5MB
- Verify file type is PDF, JPG, or PNG

**Documents not uploading:**
- Open browser console (F12)
- Look for upload errors
- Check Supabase Storage permissions
- Verify RLS policies allow authenticated users to upload

**Form not validating:**
- Ensure all required fields are filled
- Check radio buttons for medical scheme billing
- Verify document upload shows green confirmation
- Look for JavaScript errors in console

**Admin can't see application:**
- Check verification_requests table has entry
- Verify practitioner record was created
- Ensure admin user has correct role
- Check RLS policies allow admin access

## Next Steps

1. **Test the integrated registration form** in nurse.html
2. **Verify documents upload** to Supabase Storage
3. **Check admin dashboard** shows pending applications
4. **Test approval workflow** (approve, reject, request info)
5. **Verify AI recommendations** include verified practitioners
6. **Test automated reminders** (7-day, 30-day, expiry)
7. **Configure email notifications** for status changes

## Support

For issues or questions:
1. Check browser console for JavaScript errors
2. Verify Supabase configuration in config.js
3. Review RLS policies in practitioner_verification_rls.sql
4. Check database tables exist (run practitioner_verification_schema.sql)
5. Test with admin user role

---

**Integration Date:** January 2025  
**Status:** ✅ Complete  
**Location:** nurse.html (lines 126-433 HTML, lines 932+ JavaScript)
