# PRACTITIONER VERIFICATION SYSTEM - QUICK REFERENCE

## 🎯 SYSTEM OVERVIEW

Complete practitioner verification platform with 15 integrated phases:
- Database schema with RLS
- Registration workflow  
- Document upload system
- Admin review dashboard
- AI document extraction
- Automated reminders
- Trust scoring
- Reverification workflow
- Public directory with verification badges

---

## 📁 FILES CREATED

### Database Schemas (SQL)
1. **practitioner_verification_schema.sql** - Core tables and functions
2. **practitioner_verification_rls.sql** - Security policies
3. **ai_document_extraction.sql** - AI processing functions
4. **reminder_reverification_system.sql** - Automation
5. **verification_badge_display.sql** - Public views and search

### HTML Pages
1. **practitioner-register.html** - Practitioner registration (3-step wizard)
2. **admin-pharmacy-review.html** - Admin dashboard (updated with practitioner tab)

### Documentation
1. **PRACTITIONER_VERIFICATION_DEPLOYMENT.md** - Complete deployment guide

---

## 🚀 QUICK START

### 1. Run Database Migrations (in order)
```bash
# In Supabase SQL Editor
1. practitioner_verification_schema.sql
2. practitioner_verification_rls.sql  
3. ai_document_extraction.sql
4. reminder_reverification_system.sql
5. verification_badge_display.sql
```

### 2. Create Storage Bucket
```sql
INSERT INTO storage.buckets (id, name, public)
VALUES ('verification-documents', 'verification-documents', false);
```

### 3. Set Up Admin User
```sql
INSERT INTO user_role_assignments (user_id, role)
VALUES ('{admin_user_id}', 'admin');
```

### 4. Access Points
- Practitioners: `/practitioner-register.html`
- Admins: `/admin-pharmacy-review.html` → Practitioners tab

---

## 📊 DATABASE TABLES

| Table | Purpose | Key Columns |
|-------|---------|------------|
| `practitioners` | Core profiles | full_name, profession, registration_number, verification_status, trust_score |
| `documents` | Uploaded files | practitioner_id, document_type, file_url |
| `verification_requests` | Review workflow | practitioner_id, status, reviewed_by, ai_confidence_score |
| `verification_audit` | Audit trail | practitioner_id, action, notes, admin_id |
| `ai_document_extractions` | AI results | document_id, extracted_full_name, overall_match_score |
| `trust_scores` | Score breakdown | practitioner_id, total_score, component scores |

---

## 🔄 WORKFLOWS

### Practitioner Registration
```
1. Fill profile form → 2. Upload 4 documents → 3. Submit for review → 4. Wait for admin approval
```

### Admin Review
```
1. View pending list → 2. Review profile + documents → 3. Check AI results → 4. Approve/Reject/Request Info
```

### Reverification (Auto)
```
After 12 months: Verified → Expired → Notification sent → Practitioner reapplies
```

---

## 🏆 TRUST SCORE BREAKDOWN

| Component | Points | Criteria |
|-----------|--------|----------|
| Name Verified | 10 | Full name populated |
| All Documents | 10 | 4/4 documents uploaded |
| ID Document | 20 | ID uploaded |
| Registration | 40 | Verified by admin |
| Practice Number | 20 | Valid BHF number + verified |
| **TOTAL** | **100** | Auto-calculated |

---

## 🎭 USER ROLES & PERMISSIONS

### Practitioner
- ✅ View own profile
- ✅ Edit own profile  
- ✅ Upload documents
- ✅ Submit for verification
- ✅ View own audit logs
- ❌ Cannot see other practitioners

### Admin
- ✅ View all practitioners
- ✅ Review applications
- ✅ Approve/reject/request info
- ✅ View all documents
- ✅ Access audit logs
- ✅ Recalculate trust scores
- ✅ Mark as expired

### Public/Patients
- ✅ Search verified practitioners
- ✅ View verification badges
- ✅ See limited profile info
- ❌ Cannot see exact addresses
- ❌ Cannot see documents

---

## 🔍 VERIFICATION STATUSES

| Status | Meaning | Patient Visible |
|--------|---------|-----------------|
| `draft` | Just started | ❌ |
| `pending_documents` | Incomplete uploads | ❌ |
| `pending_review` | Submitted to admin | ❌ |
| `under_review` | Admin reviewing | ❌ |
| `verified` | Approved ✅ | ✅ |
| `rejected` | Denied | ❌ |
| `expired` | Needs reverification | ❌ |

---

## 🤖 AI FEATURES

### Document Extraction
- **Model:** xAI/Grok Vision
- **Extracts:**
  - Full name
  - Registration number
  - Profession
  - Institution
  - Qualification
  - Issue/expiry dates
- **Confidence:** 0-100%

### Verification Assistant
- **Compares:** AI extraction vs profile
- **Generates:** Match score (0-100%)
- **Detects:** Discrepancies
- **Assists:** Admin decision making

---

## 🔔 AUTOMATED REMINDERS

### Type 1: Incomplete Applications
- **Trigger:** 7+ days since creation
- **Status:** draft or pending_documents
- **Frequency:** Weekly

### Type 2: Expiring Soon
- **Trigger:** 30 days before expiry
- **Status:** verified
- **Frequency:** Once

### Scheduled Job
```sql
-- Run daily via pg_cron
SELECT send_verification_reminder(practitioner_id, reminder_type) 
FROM get_practitioners_needing_reminders();
```

---

## 📋 REQUIRED DOCUMENTS

1. **ID Document** - SA ID or Passport
2. **Registration Certificate** - HPCSA or SANC
3. **Degree Certificate** - Medical/Nursing qualification
4. **Proof of Address** - Recent utility bill/bank statement (<3 months)

**Formats:** PDF, JPG, PNG  
**Max Size:** 5MB per file

---

## 🔐 SECURITY FEATURES

- ✅ Row Level Security (RLS) on all tables
- ✅ Encrypted storage bucket
- ✅ User-specific folder structure
- ✅ Admin role verification
- ✅ Audit logging for all actions
- ✅ File type/size validation
- ✅ Address hidden from patients
- ✅ Secure document URLs

---

## 📱 API ENDPOINTS (Functions)

### Public Functions
```sql
-- Search verified practitioners
SELECT * FROM search_verified_practitioners(
    p_search_term := 'Smith',
    p_profession := 'Medical Practitioner',
    p_patient_lat := -26.2041,
    p_patient_lng := 28.0473,
    p_max_distance_km := 20
);

-- Get practitioner profile
SELECT get_practitioner_profile_for_patient('{practitioner_id}');
```

### Admin Functions
```sql
-- Calculate trust score
SELECT calculate_trust_score('{practitioner_id}');

-- Create audit log
SELECT create_audit_log(
    p_practitioner_id := '{id}',
    p_action := 'custom_action',
    p_notes := 'Admin note'
);

-- Expire old verifications
SELECT * FROM expire_old_verifications();
```

---

## 📊 ANALYTICS QUERIES

### Verification Stats
```sql
SELECT 
    COUNT(*) as total,
    COUNT(*) FILTER (WHERE verification_status = 'verified') as verified,
    COUNT(*) FILTER (WHERE verification_status = 'pending_review') as pending,
    ROUND(AVG(trust_score), 2) as avg_trust_score
FROM practitioners;
```

### Average Review Time
```sql
SELECT 
    ROUND(AVG(EXTRACT(EPOCH FROM (verified_at - submitted_at))/3600), 2) as avg_hours
FROM practitioners
WHERE verified_at IS NOT NULL;
```

### Expiring Soon
```sql
SELECT COUNT(*) FROM practitioners
WHERE verification_status = 'verified'
AND verification_expires_at BETWEEN NOW() AND NOW() + INTERVAL '30 days';
```

---

## 🧪 TESTING CHECKLIST

- [ ] Register new practitioner
- [ ] Upload all 4 documents
- [ ] Submit for verification
- [ ] Admin reviews application
- [ ] Approve practitioner
- [ ] Check verification badge
- [ ] Search for practitioner
- [ ] Test trust score calculation
- [ ] Test reminder system
- [ ] Test expiry workflow
- [ ] Verify audit logs
- [ ] Test RLS policies
- [ ] Check document access
- [ ] Test AI extraction (if configured)

---

## 🛠️ MAINTENANCE TASKS

### Daily (Automated)
- Expire old verifications
- Send reminders
- Check for incomplete applications

### Weekly
- Review pending applications
- Monitor approval rates
- Check trust score distribution

### Monthly
- Generate analytics reports
- Review audit logs
- Update professions list (if needed)

---

## 🎨 VERIFICATION BADGE (HTML)

```html
<!-- Verified Badge -->
<span class="badge bg-success">
    <i class="fas fa-check-circle me-1"></i>Verified Practitioner
</span>
<div class="verification-details mt-2">
    <small class="text-muted">
        <i class="fas fa-calendar me-1"></i>Verified on 22 June 2026<br>
        <i class="fas fa-certificate me-1"></i>Registration: MP123456<br>
        <i class="fas fa-shield-alt me-1"></i>Trust Score: 95/100
    </small>
</div>
```

---

## 🔗 INTEGRATION POINTS

### Patient App
```javascript
// Search practitioners
const { data: practitioners } = await supabase
    .rpc('search_verified_practitioners', {
        p_search_term: 'cardiologist',
        p_patient_lat: -26.2041,
        p_patient_lng: 28.0473
    });

// Get profile
const { data: profile } = await supabase
    .rpc('get_practitioner_profile_for_patient', {
        p_practitioner_id: practitionerId
    });
```

### Admin Dashboard
```javascript
// Load all practitioners
const { data: practitioners } = await supabase
    .from('practitioners')
    .select(`
        *,
        verification_requests (*),
        trust_scores (*),
        documents (*)
    `);

// Approve practitioner
await supabase.rpc('create_audit_log', {
    p_practitioner_id: id,
    p_action: 'practitioner_verified',
    p_admin_id: adminUserId
});
```

---

## 🎯 SUCCESS METRICS

| Metric | Target | Current |
|--------|--------|---------|
| Approval Rate | >80% | - |
| Avg Review Time | <48 hours | - |
| Trust Score Avg | >75 | - |
| AI Accuracy | >90% | - |
| Complete Applications | >90% | - |
| Reverification Rate | >95% | - |

---

## 📞 TROUBLESHOOTING

**Issue:** Documents not uploading
- Check storage bucket exists
- Verify RLS policies
- Check file size/type

**Issue:** Can't see practitioners
- Verify RLS policies
- Check user role assignment
- Ensure practitioner is verified

**Issue:** Trust score not updating
- Run `calculate_trust_score()` manually
- Check if all documents uploaded
- Verify practitioner verified

**Issue:** Reminders not sending
- Check scheduled job running
- Verify email service configured
- Review audit logs

---

## 🆘 SUPPORT QUERIES

```sql
-- Check RLS policies
SELECT * FROM pg_policies WHERE tablename = 'practitioners';

-- View audit trail for practitioner
SELECT * FROM verification_audit 
WHERE practitioner_id = '{id}' 
ORDER BY created_at DESC;

-- Check pending reviews
SELECT COUNT(*) FROM practitioners 
WHERE verification_status = 'pending_review';

-- Find practitioners needing attention
SELECT * FROM practitioners_needing_attention;
```

---

**Quick Reference Version:** 1.0  
**Last Updated:** June 22, 2026  
**Status:** ✅ Production Ready
