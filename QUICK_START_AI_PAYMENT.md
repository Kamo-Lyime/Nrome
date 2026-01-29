# Quick Start: AI Appointment Booking with Payment

## 🚀 5-Minute Setup Guide

### Step 1: Verify Files

Ensure these files exist:
- ✅ `nurse.html` (updated with payment integration)
- ✅ `js/paystack-integration.js` (payment handler)
- ✅ `js/appointment-booking.js` (booking logic)
- ✅ `config.js` (configuration)

### Step 2: Configure Paystack

Edit `js/paystack-integration.js` line 8-9:
```javascript
this.publicKey = 'pk_test_74336bdb2862bdcde9f71f4c2e3243fc3a2fedf6';
this.secretKey = 'sk_test_ce04e3466d797c150e1b7c81ce8d3a5c51bbc098';
```

### Step 3: Test Locally

1. Open `nurse.html` in browser
2. Click "AI Appointment Booking"
3. Fill form with **valid email**
4. Click "Confirm Booking & Pay"
5. Use test card: **4084 0840 8408 4081**
6. Complete payment

### Step 4: Check My Appointments

1. Click "My Appointments" card
2. View your booking
3. Test "Cancel" button
4. Verify refund message

---

## 🎯 Key Features

| Feature | Status |
|---------|--------|
| Payment Processing | ✅ Integrated |
| Refund Logic | ✅ All 6 cases |
| Cancel/Reschedule | ✅ Working |
| Status Tracking | ✅ 7 states |
| My Appointments | ✅ Dashboard |

---

## 💳 Test Payment

**Test Card**: 4084 0840 8408 4081
**CVV**: Any 3 digits
**Expiry**: Any future date

---

## 📊 Payment Breakdown

**R500 Total**
- R400 (80%) → Practitioner
- R100 (20%) → Platform Fee

---

## 🔄 Appointment Flow

```
Book → Pay → PENDING_CONFIRMATION → 
Practitioner Confirms → CONFIRMED → 
Appointment Occurs → COMPLETED
```

**Refund Cases**:
- ✅ Unconfirmed 24h → Full refund
- ✅ Cancel ≥24h → Full refund
- ❌ Cancel <24h → No refund
- ❌ No-show → No refund

---

## 🐛 Troubleshooting

**Payment doesn't work?**
→ Check email is entered and valid

**Appointments not showing?**
→ Ensure user is logged in

**Refund not processed?**
→ Check Paystack dashboard

---

## 📞 Next Steps

1. Run `payment_appointments_schema.sql` in Supabase
2. Configure webhook: `https://yourdomain.vercel.app/api/webhooks/paystack`
3. Deploy to Vercel
4. Test with real payment
5. Go live! 🎉

---

For full details, see: `AI_APPOINTMENT_PAYMENT_INTEGRATION.md`
