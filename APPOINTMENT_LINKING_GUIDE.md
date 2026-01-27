# Practitioner-Patient Appointment Linking - Implementation Guide

## Overview
This update establishes a proper connection between practitioners and patients for the appointment booking system. Now:

- **Patients** see appointments they've booked
- **Practitioners** see appointments patients have booked with them
- **Practitioners** can manage appointment status (confirm, reschedule, cancel)

---

## What Changed

### 1. Dashboard Role Detection (`js/dashboard.js`)
The dashboard now automatically detects whether a logged-in user is a **patient** or **practitioner** based on whether they have a medical practitioner profile.

```javascript
// If user has a practitioner record in medical_practitioners table → Role: Practitioner
// Otherwise → Role: Patient
```

### 2. Appointment Queries
**Before:** All appointments only showed based on `user_id` (who created the booking)

**After:**
- **Patients:** See appointments where `user_id` = their user ID
- **Practitioners:** See appointments where `practitioner_id` = their practitioner record ID

### 3. Dashboard UI Differences

#### For Patients:
- **Appointment List Title:** "Your Appointments"
- **Shows:** Practitioner name, appointment details, status
- **Actions:** View only (can see booking details)

#### For Practitioners:
- **Appointment List Title:** "Patient Appointments Booked With You"
- **Shows:** Patient name, phone, email, appointment details
- **Actions:** 
  - ✓ Confirm
  - ↻ Reschedule
  - ✗ Cancel

### 4. Database Policies (Supabase RLS)
Updated Row Level Security policies ensure:
- Patients can only see appointments they created
- Practitioners can see appointments booked with them
- Practitioners can update status of their appointments
- Data remains secure and properly separated

---

## How to Apply These Changes

### Step 1: Update Database Policies (CRITICAL)

Run the migration SQL in your Supabase dashboard:

1. Go to **Supabase Dashboard** → **SQL Editor**
2. Open the file `update_appointment_policies.sql`
3. **Copy all the SQL code** from that file
4. **Paste** into the SQL Editor
5. Click **RUN**

This updates the Row Level Security policies so practitioners can see appointments booked with them.

### Step 2: Test the Flow

#### Create Test Accounts:

**Account 1 - Practitioner:**
1. Register a new account (e.g., `doctor@test.com`)
2. Log in
3. Go to Dashboard
4. Create a **Medical Practitioner Profile**:
   - Fill in name: "Dr. Test Practitioner"
   - Profession: "General Practitioner"
   - Phone, email, etc.
   - Click "Register/Update Profile"
5. This user is now a **Practitioner**

**Account 2 - Patient:**
1. Register another account (e.g., `patient@test.com`)
2. Log in
3. Do NOT create a practitioner profile
4. This user is a **Patient**

#### Test Appointment Booking:

1. **As Patient** (`patient@test.com`):
   - Go to [nurse.html](nurse.html) or click "African Medical Practitioners"
   - Find "Dr. Test Practitioner" in the listings
   - Click **"📅 Book Appointment"**
   - Fill in patient details
   - Select date and time
   - Confirm booking
   - ✅ Appointment created

2. **Check Patient Dashboard:**
   - Go to Dashboard (as patient)
   - See the appointment under **"Your Appointments"**

3. **Check Practitioner Dashboard:**
   - Log out
   - Log in as `doctor@test.com` (the practitioner)
   - Go to Dashboard
   - See the appointment under **"Patient Appointments Booked With You"**
   - See patient name, phone, email
   - Click **✓ Confirm**, **↻ Reschedule**, or **✗ Cancel** to manage it

---

## File Changes Summary

| File | Changes Made |
|------|-------------|
| `js/dashboard.js` | • Added role detection<br>• Updated `loadAppointments()` to query based on role<br>• Added `updateAppointmentStatus()` for practitioners<br>• Added `updateDashboardUIForRole()` to change UI labels<br>• Added status badge color coding |
| `supabase_setup.sql` | • Updated appointment RLS policies<br>• Separated SELECT, INSERT, UPDATE policies<br>• Added practitioner-specific view policy |
| `update_appointment_policies.sql` | • **NEW FILE:** Migration script to update existing database<br>• Safe to run multiple times (uses DROP IF EXISTS)<br>• Includes verification queries |

---

## Technical Details

### Database Schema (appointments table)
Key columns for linking:
- `user_id` → References the patient who created the booking
- `practitioner_id` → References the practitioner record (from `medical_practitioners` table)
- `owner_user_id` (in medical_practitioners) → Links practitioner record to user account

### Query Logic

**Patient View:**
```sql
SELECT * FROM appointments 
WHERE user_id = [current_user_id]
ORDER BY appointment_date DESC;
```

**Practitioner View:**
```sql
SELECT * FROM appointments 
WHERE practitioner_id = [practitioner_record_id]
ORDER BY appointment_date DESC;
```

### Security (Row Level Security)

The RLS policies ensure:
1. **Patient sees only their bookings** (`user_id` match)
2. **Practitioner sees only bookings with them** (`practitioner_id` match via their practitioner record)
3. **No cross-user data leakage**
4. **Practitioners can't see patient appointments with other practitioners**

---

## Troubleshooting

### Issue: Practitioner doesn't see any appointments

**Cause:** RLS policies not updated in database

**Solution:**
1. Run `update_appointment_policies.sql` in Supabase SQL Editor
2. Verify policies exist: `SELECT * FROM pg_policies WHERE tablename = 'appointments';`

### Issue: Appointments show wrong information

**Cause:** Cached data or missing `practitioner_id`

**Solution:**
1. Check appointment has valid `practitioner_id` in database
2. Refresh browser (Ctrl+F5)
3. Check console for errors

### Issue: Can't update appointment status

**Cause:** Missing global function or RLS policy

**Solution:**
1. Ensure `update_appointment_policies.sql` is run
2. Clear browser cache
3. Check browser console for JavaScript errors

---

## Future Enhancements

Possible additions:
- ✉️ Email notifications when appointment status changes
- 💬 In-app messaging between patient and practitioner
- 📅 Calendar view for practitioners
- 🔔 Real-time notifications using Supabase Realtime
- 📊 Appointment analytics for practitioners

---

## Support

If you encounter issues:
1. Check browser console for errors (F12 → Console)
2. Verify database policies are created (Supabase Dashboard → Authentication → Policies)
3. Ensure both patient and practitioner accounts are set up correctly
4. Verify `practitioner_id` is saved when booking appointments

---

**Last Updated:** January 26, 2026  
**Version:** 2.0 - Practitioner-Patient Linking
