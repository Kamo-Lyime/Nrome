# Practitioner Prescription Upload System - Implementation Guide

## Overview
Practitioners can now upload prescriptions on behalf of patients. These prescriptions appear in the patient's "My Prescriptions" section and can be linked to medication orders.

---

## ✨ New Features

### For Practitioners:
1. **Upload Prescriptions for Patients**
   - Search for patients by email
   - Upload prescription files (PDF/images)
   - Automatically verified when uploaded by practitioner
   - Stored with practitioner information

2. **View Uploaded Prescriptions**
   - Dashboard shows all prescriptions they've uploaded
   - See patient details for each prescription
   - Track prescription status

### For Patients:
1. **View All Prescriptions**
   - See prescriptions uploaded by themselves OR practitioners
   - Know which practitioner uploaded each prescription
   - Link prescriptions to medication orders

---

## 🗄️ Database Changes

### New Columns in `prescriptions` Table:
```sql
practitioner_id           → Links to the practitioner who uploaded
uploaded_by_user_id       → Practitioner's user account ID
patient_name              → Patient's name for easy reference
patient_email             → Patient's email for searching
```

### Security (RLS Policies):
- **Patients:** See prescriptions where `user_id` = their user ID
- **Practitioners:** See prescriptions where `practitioner_id` = their practitioner record ID
- **Practitioners can only upload** prescriptions for patients who have booked appointments with them

---

## 🚀 How to Use

### As a Practitioner:

#### Step 1: Access Prescription Upload
1. Log into your practitioner account
2. Go to Dashboard
3. In the "Prescriptions You Uploaded" section
4. Click **"📄 Upload Prescription"** button

#### Step 2: Search for Patient
1. Enter patient's email in the search box
2. Click "Search"
3. **Note:** Only patients who have booked appointments with you will appear
4. Click on a patient to select them
5. Green highlight confirms selection

#### Step 3: Upload Prescription
1. Select prescription file (PDF or image)
2. Enter Doctor Name (required)
3. Enter Prescription Date (required)
4. Optional: Add expiry date, refills, notes
5. Click **"Upload Prescription"**

✅ **Result:**
- Prescription uploaded successfully
- Appears in your "Prescriptions You Uploaded" list
- **Automatically appears** in patient's "My Prescriptions"
- Status: **Verified** (practitioner-uploaded prescriptions are auto-verified)

### As a Patient:

#### View Your Prescriptions
1. Go to Dashboard
2. Check "My Prescriptions" section
3. See all prescriptions:
   - Ones you uploaded yourself
   - Ones practitioners uploaded for you

#### Identify Practitioner-Uploaded Prescriptions
Look for: `"Uploaded by practitioner"` tag under the doctor name

#### Link to Medication Order
1. Go to medication.html
2. Select a prescription
3. Order medications based on that prescription

---

## 📋 Complete Workflow Example

### Scenario: Dr. Smith uploads prescription for patient Jane Doe

**Step 1 - Patient Books Appointment:**
- Jane books appointment with Dr. Smith
- System records: `patient_email: jane@example.com`, `patient_name: Jane Doe`

**Step 2 - Dr. Smith Uploads Prescription:**
1. Dr. Smith logs in → Dashboard
2. Clicks "Upload Prescription"
3. Searches for: `jane@example.com`
4. Selects Jane Doe from results
5. Uploads prescription file
6. Enters details:
   - Doctor Name: Dr. John Smith
   - Date: 2026-01-26
   - Notes: "Take with food"
7. Clicks "Upload Prescription"

**Step 3 - Database Record Created:**
```javascript
{
  id: "RX-1738000000",
  file_name: "prescription.pdf",
  doctor_name: "Dr. John Smith",
  prescription_date: "2026-01-26",
  status: "Verified",
  verified: true,
  user_id: "jane-uuid",              // Jane's user ID
  practitioner_id: "drsmith-uuid",    // Dr. Smith's practitioner record
  uploaded_by_user_id: "drsmith-user-uuid", // Dr. Smith's user account
  patient_name: "Jane Doe",
  patient_email: "jane@example.com",
  notes: "Take with food"
}
```

**Step 4 - Jane Sees It:**
- Jane logs in → Dashboard
- "My Prescriptions" shows:
  ```
  Dr. Dr. John Smith
  Uploaded by practitioner
  Jan 26, 2026
  Status: Verified ✓
  Notes: Take with food
  [View Button]
  ```

**Step 5 - Jane Orders Medication:**
- Goes to medication.html
- Selects this prescription
- Orders medications
- Delivery scheduled

---

## 🔑 Key Features

✅ **Patient Search**
- Only shows patients who have booked appointments with you
- Search by email
- Shows patient name, email, phone

✅ **Auto-Verification**
- Practitioner-uploaded prescriptions = automatically verified
- No manual verification needed
- Immediate availability for medication orders

✅ **Two-Way Visibility**
- Practitioners see prescriptions they uploaded
- Patients see ALL their prescriptions (self + practitioner uploaded)

✅ **Transparent Attribution**
- Patients know which practitioner uploaded their prescription
- Practitioners track all prescriptions they've uploaded

✅ **Secure Access**
- Row Level Security ensures data privacy
- Practitioners can't see other practitioners' uploads
- Patients only see their own prescriptions

---

## 🚀 Apply Database Changes

**CRITICAL - Run This First:**

1. Open Supabase Dashboard → SQL Editor
2. Copy/paste all content from `update_appointment_policies.sql`
3. Click **RUN**

This will:
- Add new prescription columns
- Create search indices
- Update RLS policies
- Enable practitioner prescription uploads

---

## 🧪 Testing Steps

### Test 1: Practitioner Uploads Prescription

**Setup:**
1. Create Account A → Add practitioner profile → Role: Practitioner
2. Create Account B → Don't add profile → Role: Patient
3. As Patient (B) → Book appointment with Practitioner (A)

**Test Upload:**
1. Log in as Practitioner (A)
2. Dashboard → "Upload Prescription" button appears
3. Click → Modal opens
4. Search for Patient B's email
5. Select patient
6. Upload prescription file
7. Fill in details
8. Submit

**Expected Result:**
✅ Success message appears
✅ Prescription appears in "Prescriptions You Uploaded"
✅ Shows patient name and email

### Test 2: Patient Sees Prescription

1. Log out
2. Log in as Patient (B)
3. Go to Dashboard
4. Check "My Prescriptions"

**Expected Result:**
✅ Prescription appears
✅ Shows doctor name
✅ Shows "Uploaded by practitioner"
✅ Status: Verified
✅ Can click "View" button

### Test 3: Link to Medication Order

1. As Patient (B) → Go to medication.html
2. Select the prescription
3. Add medications
4. Submit order

**Expected Result:**
✅ Order created
✅ Linked to prescription
✅ Shows in deliveries

---

## 🔧 Troubleshooting

### Issue: "No patients found"

**Cause:** Patient must have booked an appointment first

**Solution:**
1. Patient must book appointment with practitioner
2. Then practitioner can search for them
3. This ensures practitioners only access their own patients

### Issue: Upload button doesn't appear

**Cause:** User is not a practitioner

**Solution:**
1. Create medical practitioner profile in dashboard
2. Reload page
3. Button should appear

### Issue: Prescription doesn't appear for patient

**Cause:** Wrong `user_id` or RLS policies not updated

**Solution:**
1. Run migration SQL script
2. Verify patient's `user_id` in database
3. Check prescription was uploaded to correct patient

---

## 📁 Modified Files

| File | Changes |
|------|---------|
| `supabase_setup.sql` | Added prescription columns, updated RLS policies |
| `update_appointment_policies.sql` | Migration script with new columns and policies |
| `js/dashboard.js` | Added prescription upload functions, patient search, role-based views |
| `dashboard.html` | Added upload prescription modal with search interface |

---

## 🎯 Benefits

1. **Streamlined Workflow:** Practitioners upload prescriptions directly for patients
2. **No Waiting:** Auto-verified prescriptions = immediate medication orders
3. **Better Communication:** Patients know who prescribed medications
4. **Accountability:** Full audit trail of who uploaded what
5. **Convenience:** Patients don't need to manually upload prescriptions from appointments

---

**Last Updated:** January 26, 2026  
**Version:** 3.0 - Practitioner Prescription Management
