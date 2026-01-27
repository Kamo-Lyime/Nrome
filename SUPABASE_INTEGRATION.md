# Supabase Database Integration Guide

## 🎯 Overview
The medication.html system now uses **Supabase** as the primary database with automatic fallback to localStorage if Supabase is unavailable.

## ✅ What's Already Done

### 1. **Supabase Client Integration**
- Supabase JavaScript library loaded via CDN
- Client initialized with your existing credentials
- Automatic connection detection and fallback

### 2. **Database Operations**
- ✅ **Prescriptions**: Upload, view, delete (Supabase + localStorage fallback)
- ✅ **Medication Orders**: Submit with full patient data (Supabase + localStorage fallback)
- ✅ **Auto-loading**: Prescriptions loaded from database on page load

### 3. **Data Tracked**

#### Prescriptions Table
- Prescription ID, file name, file data (base64)
- Doctor name, prescription date, expiry date
- Refills allowed (0-12)
- Dosage & instructions
- Upload date, verification status

#### Medication Orders Table
- Patient info (name, age, allergies, conditions, current meds)
- Medication details (name, dosage, quantity)
- Delivery info (date, time slot, address)
- Contact info (phone, emergency contact, email)
- Payment & insurance details
- Linked prescription ID (if applicable)
- Order status tracking

## 🚀 Setup Instructions

### Step 1: Access Supabase Dashboard
1. Go to [https://supabase.com](https://supabase.com)
2. Sign in to your account
3. Select your project: **vpmuooztcqzrrfsvjzwl**

### Step 2: Create Database Tables
1. Click on **SQL Editor** in the left sidebar
2. Click **New Query**
3. Open the file `supabase_setup.sql` in this folder
4. Copy ALL the SQL code
5. Paste it into the Supabase SQL Editor
6. Click **Run** (or press F5)

You should see: ✅ Success messages for each table created

### Step 3: Verify Tables
1. Click **Table Editor** in the left sidebar
2. You should now see two tables:
   - `prescriptions`
   - `medication_orders`

### Step 4: Test the System
1. Open `medication.html` in your browser
2. Open browser console (F12)
3. Look for: `✅ Supabase initialized successfully`
4. Upload a test prescription
5. Check Supabase Table Editor - you should see the prescription!

## 📊 Database Schema

### Prescriptions Table
```
id (TEXT, PRIMARY KEY) - e.g., "RX-1738632847123-0"
fileName (TEXT) - Original file name
fileData (TEXT) - Base64 encoded image/PDF
doctorName (TEXT) - Prescribing doctor
prescriptionDate (DATE) - Date prescribed
prescriptionExpiry (DATE) - Expiry date
refillsAllowed (INTEGER) - Number of refills (0-12)
notes (TEXT) - Dosage & instructions
uploadDate (TIMESTAMPTZ) - When uploaded
status (TEXT) - Pending Verification / Verified / Rejected / Expired
verified (BOOLEAN) - Pharmacist verification flag
```

### Medication Orders Table
```
orderId (TEXT, PRIMARY KEY) - e.g., "ORD-1738632847123"
patientName, patientAge, allergies, currentMedications, medicalConditions
medications (JSONB) - Array of {name, dosage, quantity}
deliveryDate, deliveryTime, deliveryAddress
phoneNumber, emergencyContact, email
insuranceProvider, insuranceNumber, paymentMethod
additionalComments
prescriptionId (TEXT, FOREIGN KEY) - Links to prescriptions table
orderDate, status, verified
```

## 🔐 Security Notes

### Current Setup (Development Mode)
- Row Level Security (RLS) is **enabled**
- Policies allow **all operations** for testing
- ⚠️ **This is NOT production-ready**

### For Production
Update RLS policies in Supabase to:
1. Require user authentication
2. Users can only see/edit their own prescriptions/orders
3. Add admin role for pharmacist verification
4. Add audit logging

Example policy (after adding auth):
```sql
-- Only show user's own prescriptions
CREATE POLICY "Users see own prescriptions" 
ON prescriptions 
FOR SELECT 
USING (auth.uid() = user_id);
```

## 🛠️ How It Works

### Automatic Fallback System
```javascript
if (USE_SUPABASE) {
    // Try Supabase first
    await supabaseClient.from('prescriptions').insert([data]);
} else {
    // Fall back to localStorage
    localStorage.setItem('prescriptions', JSON.stringify(data));
}
```

### Benefits
1. ✅ **Cloud Storage**: Data persists across devices
2. ✅ **Real-time**: Multiple users can access same data
3. ✅ **Reliable**: Automatic fallback if Supabase is down
4. ✅ **Scalable**: Can handle thousands of orders
5. ✅ **Queryable**: Easy to build admin dashboards

## 📱 Console Messages

When everything works:
```
✅ Supabase initialized successfully
🏥 Medication System Configuration:
- Database: ✅ Supabase Connected
✅ Loaded 5 prescriptions from Supabase
✅ Prescription saved to Supabase
✅ Order saved to Supabase
```

If Supabase fails:
```
⚠️ Supabase initialization failed, using localStorage fallback
🏥 Medication System Configuration:
- Database: ⚠️ localStorage Fallback
```

## 🔧 Troubleshooting

### "Supabase initialization failed"
- Check your internet connection
- Verify SUPABASE_URL and SUPABASE_ANON_KEY are correct in medication.html (lines 350-351)
- Make sure you're using the correct project URL

### "Error saving to Supabase"
- Run the SQL setup script in Supabase SQL Editor
- Check if tables exist in Table Editor
- Verify RLS policies are set correctly
- Check browser console for detailed error messages

### Tables not appearing in Supabase
- Make sure you ran ALL the SQL code from supabase_setup.sql
- Refresh the Supabase dashboard
- Check the SQL Editor output for errors

### Data not loading
- Open browser console (F12)
- Check for error messages
- Verify network tab shows successful Supabase requests
- Test with a simple prescription upload first

## 📈 Next Steps (Optional Enhancements)

1. **Add User Authentication**
   - Use Supabase Auth to track which user uploaded which prescription
   - Update RLS policies for user-specific data

2. **Admin Dashboard**
   - Create admin.html to manage all orders/prescriptions
   - Add pharmacist verification workflow
   - Order status updates

3. **Email Notifications**
   - Use Supabase Edge Functions
   - Send confirmation emails on order submission
   - Notify on prescription verification

4. **Analytics**
   - Track order statistics
   - Popular medications
   - Delivery time trends

## 🆘 Support

If you encounter issues:
1. Check browser console (F12) for error messages
2. Verify Supabase dashboard shows your data
3. Test with localStorage fallback first
4. Review the SQL setup script for any errors

---

**System Status**: ✅ Fully integrated and ready to use!
