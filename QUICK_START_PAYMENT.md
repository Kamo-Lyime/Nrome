# 🚀 QUICK START GUIDE
## Payment-Enabled Appointment Booking

Get your payment booking system live in 30 minutes.

---

## Step 1: Database (5 minutes)

1. **Open Supabase Dashboard**
   - Go to https://supabase.com/dashboard
   - Select your project

2. **Run SQL Schema**
   - Click SQL Editor (left sidebar)
   - Click "New Query"
   - Copy entire contents of `payment_appointments_schema.sql`
   - Paste into editor
   - Click "Run" button

3. **Verify Tables Created**
   ```sql
   SELECT table_name FROM information_schema.tables 
   WHERE table_schema = 'public' 
   AND table_name LIKE '%appointment%' OR table_name LIKE '%payment%';
   ```
   - Should show: `appointments`, `payment_transactions`, `practitioner_subaccounts`, `appointment_logs`

✅ **Database ready!**

---

## Step 2: Deploy Files (10 minutes)

### Upload to Your Project

1. **JavaScript Modules**
   ```
   /js/paystack-integration.js
   /js/appointment-booking.js
   ```

2. **API Endpoints**
   ```
   /api/webhooks/paystack.js
   /api/cron/appointment-automation.js
   ```

3. **HTML Page**
   ```
   /appointment-booking.html
   ```

4. **Configuration**
   - Replace existing `vercel.json` with the updated version

### Push to GitHub/Vercel

```bash
git add .
git commit -m "Add payment booking system"
git push origin main
```

Vercel will auto-deploy.

✅ **Files deployed!**

---

## Step 3: Environment Variables (5 minutes)

### In Vercel Dashboard

Go to: **Project Settings → Environment Variables**

Add these:

| Variable | Value | Where to find it |
|----------|-------|------------------|
| `SUPABASE_URL` | `https://vpmuooztcqzrrfsvjzwl.supabase.co` | Already in your config.js |
| `SUPABASE_SERVICE_ROLE_KEY` | `eyJ...` | Supabase → Settings → API → service_role key |
| `PAYSTACK_SECRET_KEY` | `sk_test_ce04e3466d797c150e1b7c81ce8d3a5c51bbc098` | Provided (test key) |

Click **Save** → **Redeploy**

✅ **Environment configured!**

---

## Step 4: Webhook Setup (5 minutes)

1. **Get Your Webhook URL**
   ```
   https://YOUR-DOMAIN.vercel.app/api/webhooks/paystack
   ```

2. **Add to Paystack**
   - Login to https://dashboard.paystack.com
   - Go to **Settings → Webhooks**
   - Click **Add Webhook**
   - Paste your webhook URL
   - Click **Save**

3. **Test Webhook**
   - In Paystack dashboard, click **Send Test Event**
   - Select `charge.success`
   - Check Vercel logs - you should see webhook received

✅ **Webhooks connected!**

---

## Step 5: Test the System (5 minutes)

### Create Test Practitioner

In Supabase SQL Editor:

```sql
INSERT INTO medical_practitioners (
    name, 
    profession, 
    email_address, 
    phone_number, 
    consultation_fee, 
    currency, 
    verified
) VALUES (
    'Dr. Test Practitioner', 
    'General Practitioner', 
    'test@example.com', 
    '+27123456789', 
    500, 
    'ZAR', 
    true
);
```

### Test Complete Flow

1. **Visit Booking Page**
   ```
   https://YOUR-DOMAIN.vercel.app/appointment-booking.html
   ```

2. **Book Appointment**
   - Select "Dr. Test Practitioner"
   - Choose tomorrow's date
   - Pick a time slot
   - Enter your details
   - Click "Pay R500"

3. **Use Test Card**
   ```
   Card Number: 4084084084084081
   CVV: 408
   Expiry: 12/25
   PIN: 0000
   ```

4. **Complete Payment**
   - Paystack modal will close
   - You'll see success message
   - Booking ID will be shown

5. **Verify in Database**
   ```sql
   SELECT * FROM appointments 
   ORDER BY created_at DESC 
   LIMIT 1;
   ```
   - Should show your appointment
   - Status: `PENDING_CONFIRMATION`
   - payment_status: `success`

✅ **System working!**

---

## Step 6: Go Live (Optional)

### Switch to Live Paystack Keys

1. **Get Live Keys**
   - Paystack Dashboard → Settings → API Keys
   - Copy Live Public Key and Secret Key

2. **Update Environment Variables**
   - Vercel → Environment Variables
   - Update `PAYSTACK_SECRET_KEY` to live key
   - Redeploy

3. **Update Frontend**
   - In `js/paystack-integration.js`
   - Change `this.publicKey` to your live public key
   - Commit and push

4. **Test with Real Card**
   - Make small test payment (R10)
   - Verify in Paystack dashboard
   - Initiate refund to test refund flow

✅ **Live and ready!**

---

## Common Issues & Fixes

### Payment Modal Not Opening

**Problem**: Click "Pay R500" but nothing happens

**Fix**:
1. Check browser console for errors
2. Verify Paystack script loaded:
   ```javascript
   console.log(typeof PaystackPop); // Should NOT be 'undefined'
   ```
3. Check `nurse.html` has:
   ```html
   <script src="https://js.paystack.co/v1/inline.js"></script>
   ```

### Appointment Not Created

**Problem**: Payment succeeds but no appointment in database

**Fix**:
1. Check Supabase logs for errors
2. Verify user is authenticated:
   ```javascript
   const { data: { user } } = await supabase.auth.getUser();
   console.log(user); // Should show user object
   ```
3. Check RLS policies allow insert

### Webhook Not Receiving Events

**Problem**: Payment succeeds but status doesn't update

**Fix**:
1. Check webhook URL is correct in Paystack
2. Check Vercel function logs for errors
3. Verify webhook signature in code
4. Test webhook manually:
   ```bash
   curl -X POST https://YOUR-DOMAIN.vercel.app/api/webhooks/paystack
   ```

### Refund Not Processing

**Problem**: Auto-refund doesn't trigger

**Fix**:
1. Check cron job is enabled (Vercel Pro required)
2. Test cron manually:
   ```bash
   curl -X POST https://YOUR-DOMAIN.vercel.app/api/cron/check-confirmations
   ```
3. Check Paystack transaction is >24h old
4. Verify Paystack secret key is correct

---

## Next Steps

After basic setup works:

1. ✅ **Add Email Notifications**
   - Integrate SendGrid or Resend
   - Send booking confirmations
   - Send appointment reminders

2. ✅ **Add SMS Notifications**
   - Integrate Africa's Talking or Twilio
   - Send SMS reminders
   - Send payment receipts

3. ✅ **Build Practitioner Dashboard**
   - Allow practitioners to confirm/decline
   - View upcoming appointments
   - Track earnings

4. ✅ **Add Analytics**
   - Track booking conversion rate
   - Monitor refund rate
   - Track revenue

5. ✅ **Legal Compliance**
   - Review Terms & Conditions with lawyer
   - Add Privacy Policy page
   - Ensure POPIA compliance

---

## Support Resources

- 📖 **Full Documentation**: `PAYMENT_BOOKING_GUIDE.md`
- ✅ **Detailed Checklist**: `IMPLEMENTATION_CHECKLIST.md`
- 📜 **Terms Template**: `TERMS_AND_CONDITIONS.md`

---

## Quick Reference

### Test Paystack Card
```
Card: 4084084084084081
CVV: 408
Expiry: Any future date
PIN: 0000
```

### Important URLs
```
Appointment Booking: https://YOUR-DOMAIN.vercel.app/appointment-booking.html
Webhook Endpoint: https://YOUR-DOMAIN.vercel.app/api/webhooks/paystack
Cron Check: https://YOUR-DOMAIN.vercel.app/api/cron/check-confirmations
```

### Key SQL Queries

**View Recent Appointments:**
```sql
SELECT booking_id, patient_name, status, amount_paid, created_at
FROM appointments
ORDER BY created_at DESC
LIMIT 10;
```

**View Payment Transactions:**
```sql
SELECT reference, transaction_type, amount, status, created_at
FROM payment_transactions
ORDER BY created_at DESC
LIMIT 10;
```

**Check Pending Confirmations:**
```sql
SELECT * FROM pending_confirmations;
```

**Revenue Summary:**
```sql
SELECT * FROM payment_summary
ORDER BY transaction_date DESC
LIMIT 7;
```

---

## Success! 🎉

Your payment booking system is now live. Patients can book and pay instantly, practitioners get automatic payouts, and everything is tracked with full audit trails.

**Need help?** Check the full guides or open an issue.

**Ready to scale?** Review the scaling section in `PAYMENT_BOOKING_GUIDE.md`.
