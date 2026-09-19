# PRACTITIONER ACCOUNT & APPOINTMENT BOOKING FIX

## Problem Summary

Your appointments were failing to save to Supabase and falling back to localStorage due to three critical issues:

### Issue 1: Table Name Mismatch
- **Problem**: `nurse.html` was querying from table `'practitioners'` but the database uses `'medical_practitioners'`
- **Result**: Practitioner listings were either empty or pulling from wrong table
- **Fix**: Changed `DB_TABLES.practitioners` from `'practitioners'` to `'medical_practitioners'` in nurse.html

### Issue 2: Missing Practitioner Records
- **Problem**: When users signed up with role "practitioner", only their auth account was created, NOT a record in `medical_practitioners` table
- **Result**: When patients tried to book appointments, the `practitioner_id` didn't exist, causing foreign key constraint violation:
  ```
  "insert or update on table 'appointments' violates foreign key constraint 'appointments_practitioner_id_fkey'"
  "Key is not present in table 'medical_practitioners'"
  ```
- **Fix**: Updated `auth.js` to automatically create a `medical_practitioners` record when users sign up as practitioner

### Issue 3: No Database Trigger
- **Problem**: No database-level trigger to ensure practitioner profiles are created
- **Fix**: Created SQL script `fix_practitioner_accounts.sql` that adds a trigger to auto-create practitioner profiles

## Files Changed

### 1. nurse.html
**Location**: Line 980
**Change**: 
```javascript
// BEFORE
practitioners: 'practitioners',

// AFTER
practitioners: 'medical_practitioners',
```

### 2. js/auth.js
**Location**: `wireRegisterForm()` function
**Change**: Added automatic practitioner profile creation when role='practitioner'
```javascript
// Now creates medical_practitioners record automatically on signup
if (role === 'practitioner' && authData?.user?.id) {
    const practitionerProfile = {
        owner_user_id: authData.user.id,
        name: fullName,
        profession: 'Medical Practitioner',
        email_address: email,
        verified: false,
        // ... other fields
    };
    
    await supabaseClient
        .from('medical_practitioners')
        .insert([practitionerProfile]);
}
```

## How to Apply the Fix

### Step 1: Run Database Scripts
Run these scripts in your Supabase SQL Editor in this order:

1. **fix_practitioner_accounts.sql** - Creates missing practitioner profiles for existing users and adds trigger
2. **verify_appointments_foreign_keys.sql** - Fixes any orphaned appointments

### Step 2: Clear Browser Data (Optional but Recommended)
Since appointments were being stored in localStorage as a fallback:
1. Open browser console (F12)
2. Go to Application/Storage tab
3. Clear localStorage for your site
4. Or run: `localStorage.removeItem('appointments')`

### Step 3: Test the Fix

#### Test 1: New Practitioner Signup
1. Go to index.html
2. Create a new account with role "Practitioner"
3. Check that a record is automatically created in `medical_practitioners` table
4. Verify the practitioner appears on nurse.html

#### Test 2: Appointment Booking
1. Go to nurse.html
2. Select a practitioner
3. Fill in appointment details
4. Complete payment
5. **VERIFY**: Appointment saves to Supabase `appointments` table (check via SQL or Supabase dashboard)
6. **VERIFY**: No localStorage fallback message appears

#### Test 3: Dashboard View
1. Login as the practitioner
2. Go to dashboard.html
3. Verify appointments show up (not from localStorage)
4. Verify role is correctly detected as "practitioner"

## What Was Working Before?

You mentioned everything worked when you had 20%/80% payment split. Looking at your schemas:

**payment_appointments_schema.sql** (old working version):
- Correctly referenced `medical_practitioners` table
- Appointments were saving because practitioner records existed
- Either:
  - You were manually creating practitioner profiles, OR
  - You had a different registration flow that created profiles

**What Changed:**
- Schema updates for new pricing (5%/95% split) were applied
- Table naming got inconsistent between files
- Registration flow lost the practitioner profile creation step

## Database Schema Reference

### medical_practitioners Table
```sql
CREATE TABLE medical_practitioners (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID REFERENCES auth.users(id), -- Links to auth user
    name TEXT NOT NULL,
    profession TEXT NOT NULL,
    license_number TEXT,
    service_description TEXT,
    consultation_fee NUMERIC,
    currency TEXT,
    serving_locations TEXT,
    availability TEXT,
    phone_number TEXT,
    email_address TEXT,
    verified BOOLEAN DEFAULT FALSE,
    rating NUMERIC DEFAULT 0,
    total_patients INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### appointments Table (Foreign Key)
```sql
CREATE TABLE appointments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    practitioner_id UUID REFERENCES medical_practitioners(id), -- THIS MUST EXIST!
    -- other fields...
);
```

## Preventing This Issue in the Future

### 1. Always Use Consistent Table Names
Make sure all files reference the same table:
- ✅ `medical_practitioners` (current standard)
- ❌ Don't mix with `practitioners` unless you're migrating schemas

### 2. Test Registration Flow
When adding new user types:
1. Create auth account
2. Create corresponding profile record in related table
3. Test foreign key relationships

### 3. Monitor Foreign Key Violations
Set up error logging to catch foreign key violations early:
```javascript
const { data, error } = await supabaseClient
    .from('appointments')
    .insert(appointmentData);

if (error && error.code === '23503') {
    console.error('Foreign key violation - practitioner_id does not exist!');
    // Don't fall back to localStorage, show user error
}
```

### 4. Use Database Triggers
The new trigger ensures consistency even if frontend code fails:
```sql
CREATE TRIGGER on_auth_user_created_create_practitioner
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION handle_new_practitioner_signup();
```

## Verification Checklist

After applying fixes:

- [ ] All practitioner users have records in `medical_practitioners` table
- [ ] New practitioner signups automatically create profiles
- [ ] Practitioners appear on nurse.html practitioner list
- [ ] Appointment bookings save to Supabase (not localStorage)
- [ ] No foreign key constraint violations in console
- [ ] Practitioners can view their appointments on dashboard
- [ ] Patients can view their appointments on dashboard

## Support Commands

### Check if practitioner profile exists for a user:
```sql
SELECT mp.* 
FROM medical_practitioners mp
JOIN auth.users au ON mp.owner_user_id = au.id
WHERE au.email = 'practitioner@example.com';
```

### Create practitioner profile manually (if needed):
```sql
INSERT INTO medical_practitioners (
    owner_user_id,
    name,
    profession,
    email_address
) VALUES (
    'USER_ID_HERE',
    'Dr. Name',
    'Medical Practitioner',
    'email@example.com'
);
```

### Check for orphaned appointments:
```sql
SELECT a.*
FROM appointments a
WHERE a.practitioner_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM medical_practitioners mp 
      WHERE mp.id = a.practitioner_id
  );
```

## Summary

✅ **Fixed**: Table name mismatch in nurse.html  
✅ **Fixed**: Automatic practitioner profile creation on signup  
✅ **Added**: Database trigger for fail-safe profile creation  
✅ **Created**: Migration scripts for existing users  

🎯 **Result**: Appointments will now save to Supabase successfully!
