# 🚀 Quick Start - Practitioner Verification System

## Get Started in 5 Minutes

### Step 1: Database Setup (2 minutes)

Open Supabase SQL Editor and run these files **in order**:

```sql
-- 1. Create tables
-- Run: practitioner_verification_schema.sql
-- Creates: practitioners, practitioner_documents, verification_requests, 
--          verification_audit, ai_document_extractions, trust_scores

-- 2. Set up security
-- Run: practitioner_verification_rls.sql
-- Creates: Row Level Security policies for all tables

-- 3. AI extraction (optional, needs xAI API key)
-- Run: ai_document_extraction.sql
-- Creates: Functions for AI document analysis

-- 4. Automation (optional, requires pg_cron extension)
-- Run: reminder_reverification_system.sql
-- Creates: Automated reminders and expiry workflows

-- 5. Public search (optional)
-- Run: verification_badge_display.sql
-- Creates: Public functions for searching verified practitioners
```

**Quick verify:**
```sql
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('practitioners', 'practitioner_documents', 'verification_requests');
```
Should return 3 rows ✅

---

### Step 2: Create Storage Bucket (1 minute)

1. **Supabase Dashboard** → **Storage** → **New bucket**
2. **Bucket name:** `verification-documents`
3. **Public bucket:** ✅ Checked
4. **Create bucket**

**File size limits:**
- Go to bucket settings
- Set max file size: **5 MB**

**RLS Policy** (already in practitioner_verification_rls.sql):
```sql
-- Allows authenticated users to upload to verification-documents
-- Allows public to view verified documents
-- Allows admins to delete
```

---

### Step 3: Test Registration Flow (2 minutes)

#### A. Open nurse.html
```
File: c:\Users\Kamono\Desktop\Nromebasic\nurse.html
```

#### B. Click Registration Button
- Find: **"Register Your Medical Practice"** (green button with +)
- Click to expand form

#### C. Fill Step 1 - Quick Test Data
```
Full Name: Test Practitioner
Profession: Medical Practitioner
Registration Number: MP000001
Practice Number: 1234567
Specialty: General Practice
Practice Name: Test Clinic
Address: 123 Test St, Johannesburg, 2000
Medical Scheme: Yes
```
Click: **Next: Upload Documents ➡️**

#### D. Upload Step 2 - Use Any Files
- Prepare 4 test files (any PDF or image < 5MB)
- Drag or click to upload each:
  1. ID Document
  2. Registration Certificate
  3. Degree Certificate
  4. Proof of Address
  
Click: **Next: Review & Submit ➡️**

#### E. Submit Step 3
- Review shows all your data
- Click: **Submit for Verification** (big green button)
- Wait 3-5 seconds
- ✅ Success message appears!

---

### Step 4: Verify in Database (30 seconds)

**Open Supabase Dashboard → Table Editor:**

#### Check Practitioner Record
```sql
SELECT * FROM practitioners ORDER BY created_at DESC LIMIT 1;
```
Expected:
- full_name: "Test Practitioner"
- verification_status: "pending_review"
- Created just now ✅

#### Check Documents
```sql
SELECT document_type, file_name FROM practitioner_documents 
WHERE practitioner_id = (SELECT id FROM practitioners ORDER BY created_at DESC LIMIT 1);
```
Expected: 4 rows ✅

#### Check Storage
**Storage → verification-documents bucket**
Should see 4 files uploaded ✅

---

### Step 5: Admin Review (1 minute)

#### A. Open Admin Dashboard
```
File: c:\Users\Kamono\Desktop\Nromebasic\admin-pharmacy-review.html
```

#### B. View Pending Applications
- Click: **Practitioners tab**
- See: Your test application in table
- Status: **Pending Review** (yellow)

#### C. Review Application
- Click: **Review** button
- Modal opens showing:
  - Profile information
  - 4 document links (click to view)
  - Trust score
  - AI confidence (if enabled)

#### D. Approve
- Click: **✅ Approve** button
- Status changes to: **Verified** (green)
- Modal closes

---

### Step 6: Verify Approval (30 seconds)

#### A. Check Database
```sql
SELECT verification_status FROM practitioners 
WHERE full_name = 'Test Practitioner';
```
Expected: `verified` ✅

#### B. Check Listing
Return to **nurse.html**
- Scroll to "All Available Registered Medical Practitioners"
- Your verified practitioner should appear
- Shows verification badge ✅

---

## ✅ You're Done!

**What You've Just Set Up:**
- ✅ Complete practitioner verification system
- ✅ 3-step registration wizard with document upload
- ✅ Secure Supabase Storage integration
- ✅ Admin review dashboard
- ✅ Trust score calculation
- ✅ Verification workflow (pending → under review → verified)

---

## Next Steps

### 1. Configure AI Document Extraction (Optional)

**Get xAI API Key:**
1. Sign up at: https://x.ai/api
2. Create API key
3. Add to config.js:
```javascript
const XAI_API_KEY = 'xai-your-key-here';
const XAI_API_URL = 'https://api.x.ai/v1';
```

**The AI will:**
- Extract text from uploaded documents
- Validate registration numbers match certificates
- Detect name discrepancies
- Calculate confidence scores
- Help admins review faster

---

### 2. Enable Automated Reminders (Optional)

**Requires pg_cron extension:**
```sql
-- Enable extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Run reminder_reverification_system.sql
-- This creates:
-- - 7-day incomplete application reminders
-- - 30-day expiry warnings
-- - 12-month auto-expiry (reverification required)
```

---

### 3. Customize for Your Needs

**Add More Professions:**
Edit [nurse.html](nurse.html) line ~225:
```html
<option value="Your New Profession">Your New Profession</option>
```

**Change Document Requirements:**
Edit Step 2 document upload sections (lines ~317-385)

**Adjust Trust Score Weights:**
Edit `calculate_trust_score()` function in:
- practitioner_verification_schema.sql

**Custom Verification Statuses:**
Add to ENUM in schema:
```sql
ALTER TYPE verification_status_enum ADD VALUE 'your_custom_status';
```

---

## Troubleshooting

### ❌ "Supabase client not configured"

**Check config.js:**
```javascript
const SUPABASE_URL = 'https://your-project.supabase.co';
const SUPABASE_ANON_KEY = 'your-anon-key-here';

const supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
```

### ❌ Documents not uploading

**Check bucket exists:**
- Supabase Dashboard → Storage
- Should see: `verification-documents` bucket
- Status: Public ✅

**Check RLS policies:**
```sql
SELECT * FROM pg_policies WHERE tablename = 'objects' AND schemaname = 'storage';
```

### ❌ Form won't submit

**Browser console (F12):**
- Look for red errors
- Common issues:
  - User not authenticated
  - Missing required fields
  - File size > 5MB
  - Invalid file type

### ❌ Admin can't see applications

**Check user role:**
```sql
SELECT auth.uid(), auth.role();
```

**Check RLS policies allow admin:**
```sql
SELECT * FROM verification_requests; -- Should return rows
```

---

## File Reference

| File | Purpose | Location |
|------|---------|----------|
| nurse.html | Registration wizard | Main page with collapsible form |
| admin-pharmacy-review.html | Admin dashboard | Review and approve applications |
| practitioner_verification_schema.sql | Database tables | Run first in Supabase |
| practitioner_verification_rls.sql | Security policies | Run second |
| ai_document_extraction.sql | AI features | Optional, needs API key |
| reminder_reverification_system.sql | Automation | Optional, needs pg_cron |

---

## Documentation

📚 **Full Guides:**
- [PRACTITIONER_REGISTRATION_INTEGRATED.md](PRACTITIONER_REGISTRATION_INTEGRATED.md) - Complete integration guide
- [PRACTITIONER_REGISTRATION_TEST_GUIDE.md](PRACTITIONER_REGISTRATION_TEST_GUIDE.md) - Testing scenarios
- [INTEGRATION_COMPLETE_SUMMARY.md](INTEGRATION_COMPLETE_SUMMARY.md) - What changed
- [PRACTITIONER_VERIFICATION_FLOW_DIAGRAM.md](PRACTITIONER_VERIFICATION_FLOW_DIAGRAM.md) - Visual flow

📖 **Quick Reference:**
- [PRACTITIONER_QUICK_REFERENCE.md](PRACTITIONER_QUICK_REFERENCE.md) - Quick commands
- [PRACTITIONER_VERIFICATION_DEPLOYMENT.md](PRACTITIONER_VERIFICATION_DEPLOYMENT.md) - Deployment steps

---

## Support

**Common Questions:**

**Q: Can I test without Supabase?**  
A: Basic testing works with localStorage fallback, but document upload requires Supabase.

**Q: How do I make someone an admin?**  
A: Admins are identified by user_id or role in RLS policies. Check practitioner_verification_rls.sql.

**Q: Can I change the 4 required documents?**  
A: Yes! Edit Step 2 HTML in nurse.html and update ENUM in schema.

**Q: How long does verification take?**  
A: Admin review typically takes 2-3 business days. Automated reminders sent after 7 days.

**Q: Can practitioners update their documents?**  
A: Currently no. Future feature: reverification workflow allows document re-upload.

---

## Success Checklist

- [ ] Database tables created (6 tables)
- [ ] RLS policies applied
- [ ] Storage bucket created (`verification-documents`)
- [ ] Config.js has Supabase credentials
- [ ] Registration form opens in nurse.html
- [ ] Can complete all 3 steps
- [ ] Documents upload to Storage
- [ ] Success message appears
- [ ] Application appears in admin dashboard
- [ ] Admin can approve application
- [ ] Verified practitioner appears in listings
- [ ] No errors in browser console

---

**Status:** ✅ Ready to Use  
**Setup Time:** ~5 minutes  
**Difficulty:** Beginner  

🎉 **Congratulations!** Your practitioner verification system is live!
