## Practitioner Public Listing Fixes

### Issues Fixed:

1. **"null" showing instead of specialty**
   - Changed "Qualifications" label to "Specialty" 
   - Added fallback: `specialty || qualifications || 'General Practice'`
   - Added null check: only shows if value exists and !== 'null'

2. **"null" showing for service description**
   - Added null check: `serviceDescription && serviceDescription !== 'null'`
   - Fallback to `practice_name` if `service_description` is empty
   - Only displays if value exists

3. **Medical Aid acceptance not shown**
   - Added `acceptsMedicalAid` parameter to `createServiceListing()`
   - Added blue info badge: "Accepts Medical Aid" with check icon
   - Reads from `medical_scheme_billing_supported` column

4. **Missing default currency**
   - Added fallback: `currency || 'ZAR'`

### Files Changed:

1. **[nurse.html](nurse.html)**:
   - Line ~1754: Added `acceptsMedicalAid` parameter to function signature
   - Line ~951: Updated function call to pass medical aid flag
   - Line ~1781: Updated card template with specialty label, medical aid badge, null checks

### SQL Migration:

**[add_practitioner_profile_columns.sql](add_practitioner_profile_columns.sql)**
- Adds missing columns to `practitioners` table:
  - `consultation_fee`, `currency`, `availability`
  - `experience_years`, `serving_locations`, `service_description`
  - `profile_image_url`, `qualifications`
  
Run this script if the columns don't exist in your database.

### Result:

Practitioner listings now show:
- ✅ **Specialty** (not "null")
- ✅ **Medical Aid badge** (blue info badge with check icon)
- ✅ **No more "null" text** in descriptions
- ✅ **Proper default currency** (ZAR)

### Test:

1. Hard refresh [nurse.html](nurse.html)
2. Check public practitioner listing
3. Should see proper specialty and medical aid badge
