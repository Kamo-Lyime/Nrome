# Quick Test Guide - Practitioner Registration in nurse.html

## Prerequisites
✅ Supabase project configured with URL and anon key in `config.js`  
✅ Database schema created (run `practitioner_verification_schema.sql`)  
✅ RLS policies applied (run `practitioner_verification_rls.sql`)  
✅ Storage bucket `verification-documents` created  
✅ User authenticated (logged in)

## Test Scenario 1: Registration Happy Path

### 1. Open nurse.html
```
Open: c:\Users\Kamono\Desktop\Nromebasic\nurse.html
```

### 2. Locate Registration Button
- Scroll to find **"Register Your Medical Practice"** button
- Should be a green/blue button with + icon
- Located above "All Available Registered Medical Practitioners" section

### 3. Open Registration Form
**Action:** Click "Register Your Medical Practice"

**Expected:**
- ✅ Form expands (slides down)
- ✅ Button changes to "Close Registration Form" (minus icon)
- ✅ Step indicator visible with 3 steps
- ✅ Step 1 is highlighted (blue/active)
- ✅ Profile Information form is visible

### 4. Fill Step 1 - Profile Information
**Fill in these fields:**

| Field | Example Value |
|-------|--------------|
| Full Name | Dr. Sarah Johnson |
| Profession | Medical Practitioner |
| Registration Number | MP0123456 |
| Practice Number | 1234567 |
| Specialty | General Practice |
| Practice Name | Johnson Medical Centre |
| Practice Address | 123 Main Street, Johannesburg, 2000 |
| Medical Scheme Billing | Yes |

**Action:** Click **"Next: Upload Documents"**

**Expected:**
- ✅ No validation errors
- ✅ Step 1 turns green (completed)
- ✅ Step 2 highlights blue (active)
- ✅ Document upload section visible

### 5. Upload Step 2 - Documents
**Prepare 4 test files:**
- Any PDF or image file (rename for clarity)
  1. `id_document.pdf`
  2. `registration_cert.pdf`
  3. `degree.pdf`
  4. `proof_address.pdf`

**For each document area:**

**Option A: Click to Upload**
1. Click on upload area
2. Select file from file picker
3. Wait for green confirmation

**Option B: Drag and Drop**
1. Drag file from file explorer
2. Drop on upload area
3. Upload area turns green
4. File preview appears below

**Expected for each upload:**
- ✅ Upload area border turns green
- ✅ File name displays in preview box
- ✅ File size shown (e.g., "245 KB")
- ✅ File icon displays (PDF or image icon)
- ✅ Red "trash" button to remove

**Action:** Click **"Next: Review & Submit"** (only enabled when all 4 uploaded)

**Expected:**
- ✅ Step 2 turns green (completed)
- ✅ Step 3 highlights blue (active)
- ✅ Review summary visible

### 6. Review Step 3 - Submit
**Verify review summary shows:**

**Profile Information Card:**
- Full Name: Dr. Sarah Johnson
- Profession: Medical Practitioner
- Registration Number: MP0123456
- Practice Number: 1234567
- Specialty: General Practice
- Practice Name: Johnson Medical Centre
- Medical Scheme Billing: Yes
- Practice Address: 123 Main Street, Johannesburg, 2000

**Uploaded Documents Card:**
- ✅ 4 documents uploaded
- ID Document: id_document.pdf
- Registration Certificate: registration_cert.pdf
- Degree Certificate: degree.pdf
- Proof of Address: proof_address.pdf

**What Happens Next Section:**
- Should explain verification process
- Mentions 2-3 business days review time

**Action:** Click **"Submit for Verification"** (big green button)

**Expected:**
- ✅ Button shows "Submitting Application..." with spinner
- ✅ After 3-5 seconds: Success screen appears
- ✅ Green checkmark icon
- ✅ "Application Submitted Successfully!" heading
- ✅ Submission date/time displayed
- ✅ "Application Status: Pending Review"

### 7. Close Form
**Action:** Click **"Close"** button

**Expected:**
- ✅ Form collapses (slides up)
- ✅ Button returns to "Register Your Medical Practice" (plus icon)
- ✅ Wizard resets to Step 1 (for next registration)

### 8. Verify in Database
**Open Supabase Dashboard:**

**Check `practitioners` table:**
```sql
SELECT * FROM practitioners ORDER BY created_at DESC LIMIT 1;
```
Expected fields:
- full_name: "Dr. Sarah Johnson"
- profession: "Medical Practitioner"
- verification_status: "pending_documents" or "pending_review"

**Check `practitioner_documents` table:**
```sql
SELECT * FROM practitioner_documents WHERE practitioner_id = (SELECT id FROM practitioners ORDER BY created_at DESC LIMIT 1);
```
Expected: 4 rows (one for each document)

**Check `verification_requests` table:**
```sql
SELECT * FROM verification_requests WHERE practitioner_id = (SELECT id FROM practitioners ORDER BY created_at DESC LIMIT 1);
```
Expected: 1 row with status "pending_review"

**Check Supabase Storage:**
1. Navigate to Storage → verification-documents bucket
2. Should see 4 files uploaded
3. File names format: `{userId}_{docType}_{timestamp}_{originalName}`

---

## Test Scenario 2: Validation Errors

### Missing Required Fields
**Action:** Fill only "Full Name" in Step 1, click "Next"

**Expected:**
- ❌ Error message: "Please fill in: Profession"
- ❌ Field highlights red
- ❌ Cannot proceed to Step 2

### Missing Medical Scheme Selection
**Action:** Fill all fields but don't select "Yes" or "No" for medical scheme

**Expected:**
- ❌ Error: "Please indicate if you support medical scheme billing"
- ❌ Cannot proceed

### Upload Wrong File Type
**Action:** Try uploading a .docx or .txt file

**Expected:**
- ❌ Error: "Please upload PDF, JPG, or PNG files only"
- ❌ File input clears
- ❌ No preview shown

### Upload Oversized File
**Action:** Try uploading file > 5MB

**Expected:**
- ❌ Error: "File size must be less than 5MB"
- ❌ File input clears

### Submit Without All Documents
**Action:** Upload only 3 of 4 documents, click "Next"

**Expected:**
- ❌ Error: "Please upload all required documents before continuing"
- ❌ Cannot proceed to Step 3

---

## Test Scenario 3: Navigation

### Back Button from Step 2
**Action:**
1. Complete Step 1, proceed to Step 2
2. Click "Back" button

**Expected:**
- ✅ Returns to Step 1
- ✅ All filled data is preserved
- ✅ Step 2 not marked as completed

### Back from Step 3
**Action:**
1. Complete Steps 1 and 2
2. On review screen, click "Back"

**Expected:**
- ✅ Returns to Step 2
- ✅ All uploaded documents still visible
- ✅ Can add/remove documents

### Cancel Button
**Action:** On Step 1, click "Cancel" button

**Expected:**
- ✅ Form closes/collapses
- ✅ Data is cleared
- ✅ Button reverts to "Register Your Medical Practice"

---

## Test Scenario 4: Admin Review

### 1. Open Admin Dashboard
```
Open: c:\Users\Kamono\Desktop\Nromebasic\admin-pharmacy-review.html
```

### 2. Switch to Practitioners Tab
**Action:** Click **"Practitioners"** tab

**Expected:**
- ✅ Table shows pending applications
- ✅ Recent submission (Dr. Sarah Johnson) visible
- ✅ Status: "Pending Review" (yellow badge)
- ✅ "Review" button in Actions column

### 3. Open Review Modal
**Action:** Click **"Review"** button

**Expected:**
- ✅ Modal opens
- ✅ Shows all profile information
- ✅ Shows 4 documents with clickable links
- ✅ Trust score displayed (calculated automatically)
- ✅ 3 action buttons: Approve, Reject, Request More Info

### 4. Review Documents
**Action:** Click each document link

**Expected:**
- ✅ Opens in new tab
- ✅ Shows uploaded PDF/image
- ✅ URL is from Supabase Storage

### 5. Approve Application
**Action:** Click **"Approve"** button

**Expected:**
- ✅ Success message
- ✅ Status changes to "Verified" (green badge)
- ✅ Modal closes
- ✅ Database `verification_status` = "verified"

---

## Test Scenario 5: Drag and Drop

### 1. Open Registration Form
**Action:** Click "Register Your Medical Practice"

### 2. Navigate to Step 2
**Action:** Fill Step 1, click "Next"

### 3. Test Drag Over
**Action:** Drag file from file explorer, hover over upload area (don't drop)

**Expected:**
- ✅ Upload area border turns green
- ✅ Background color changes to light green

### 4. Drop File
**Action:** Release file on upload area

**Expected:**
- ✅ File uploads
- ✅ Preview appears
- ✅ Upload area stays green

### 5. Drag Away
**Action:** Drag file over upload area, then drag away without dropping

**Expected:**
- ✅ Border returns to gray
- ✅ Background returns to normal

---

## Test Scenario 6: Multiple Registrations

### 1. Submit First Registration
**Action:** Complete full registration for "Dr. Sarah Johnson"

### 2. Close and Reopen Form
**Action:**
1. Click "Close"
2. Click "Register Your Medical Practice" again

**Expected:**
- ✅ Form is completely reset
- ✅ Step 1 is active
- ✅ All fields are empty
- ✅ No documents uploaded

### 3. Submit Second Registration
**Action:** Fill different data (e.g., "Dr. Michael Brown")

**Expected:**
- ✅ Both registrations exist in database
- ✅ No data mixing between registrations
- ✅ Each has own set of documents

---

## Browser Console Tests

### 1. Check for JavaScript Errors
**Action:**
1. Press F12 to open Developer Tools
2. Go to Console tab
3. Perform registration

**Expected:**
- ✅ No red errors
- ✅ Only info/debug logs (if any)
- ✅ Success logs on submission

### 2. Check Network Activity
**Action:**
1. Open Network tab in Developer Tools
2. Submit registration
3. Watch API calls

**Expected:**
- ✅ POST requests to Supabase Storage (4 document uploads)
- ✅ POST to practitioners table
- ✅ POST to practitioner_documents table (4 inserts)
- ✅ POST to verification_requests table
- ✅ All return 200/201 status codes

---

## Common Issues and Fixes

### Issue: "Supabase client not configured"
**Fix:**
```javascript
// Check config.js has:
const SUPABASE_URL = 'your-project-url';
const SUPABASE_ANON_KEY = 'your-anon-key';
```

### Issue: Documents not uploading
**Fix:**
1. Create bucket in Supabase Storage: `verification-documents`
2. Set bucket to public
3. Check RLS policies allow INSERT

### Issue: Form doesn't expand
**Fix:**
```javascript
// Verify buttons exist:
document.getElementById('openFormBtn')
document.getElementById('closeFormBtn')
document.getElementById('registrationForm')
```

### Issue: Step navigation not working
**Fix:**
```javascript
// Check global functions are defined:
window.goToRegistrationStep
window.triggerFileUpload
window.handleFileSelect
window.removeDocument
window.submitPractitionerApplication
```

---

## Success Criteria

✅ All 3 steps navigate correctly  
✅ Form validation prevents invalid submissions  
✅ All 4 documents upload to Supabase Storage  
✅ Practitioner record created in database  
✅ Document records linked to practitioner  
✅ Verification request created  
✅ Success message displays  
✅ Form resets on close  
✅ Admin can review application  
✅ No JavaScript errors in console  

---

**Test Date:** _______________  
**Tester:** _______________  
**Status:** _______________  
**Issues Found:** _______________
