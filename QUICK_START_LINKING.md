## Quick Start: Linking Patients & Practitioners

### 1️⃣ Update Database (REQUIRED - Do This First!)
Open Supabase SQL Editor and run: `update_appointment_policies.sql`

### 2️⃣ How It Works Now

**PATIENT ACCOUNT:**
- Books appointments → sees them in "Your Appointments"
- Views practitioner details

**PRACTITIONER ACCOUNT:**  
- Creates profile on dashboard → becomes a practitioner
- Sees "Patient Appointments Booked With You"
- Can Confirm ✓, Reschedule ↻, or Cancel ✗ appointments

### 3️⃣ Test Steps

1. Create Account A → Add practitioner profile → This is PRACTITIONER
2. Create Account B → Don't add profile → This is PATIENT  
3. Login as PATIENT → Book appointment with PRACTITIONER
4. Login as PRACTITIONER → See booking in dashboard with patient details
5. Click status buttons to manage appointment

### 4️⃣ Key Files Changed
- `js/dashboard.js` - Role detection & appointment queries
- `supabase_setup.sql` - Updated RLS policies  
- `update_appointment_policies.sql` - Migration for existing DB

### 5️⃣ Verification
✅ Patients see appointments they booked
✅ Practitioners see appointments booked WITH them  
✅ Status buttons work (Confirm/Reschedule/Cancel)
✅ No cross-user data leakage

📖 Full guide: `APPOINTMENT_LINKING_GUIDE.md`
