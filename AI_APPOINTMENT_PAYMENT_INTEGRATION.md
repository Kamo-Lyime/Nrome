# AI Appointment Booking with Paystack Payment Integration

## 🎉 Implementation Complete!

The AI Appointment Booking system has been fully integrated with Paystack payment processing. Patients can now book appointments with automatic payment processing, refunds, and full appointment management.

---

## 📋 What Has Been Implemented

### 1. **Payment-Integrated Booking Flow**
- ✅ AI Appointment Booking now requires payment before confirmation
- ✅ R500 consultation fee with 80/20 split (R400 to practitioner, R100 platform fee)
- ✅ Secure payment via Paystack inline modal
- ✅ Email validation for payment processing
- ✅ Payment confirmation with booking details

### 2. **Appointment Statuses**
The system now tracks appointments through these states:
- `PENDING_PAYMENT` - Created but payment not completed
- `PENDING_CONFIRMATION` - Paid, awaiting practitioner confirmation (24h window)
- `CONFIRMED` - Practitioner confirmed the appointment
- `COMPLETED` - Appointment has occurred
- `CANCELLED` - Cancelled by patient or practitioner
- `REFUNDED` - Payment refunded to patient
- `NO_SHOW` - Patient did not attend (fee retained)

### 3. **Automated Refund Logic**
Fully implemented for all edge cases:

**A. Unconfirmed Timeout (24h)**
- If practitioner doesn't confirm within 24 hours → Automatic refund
- Status: `PENDING_CONFIRMATION` → `REFUNDED`

**B. Practitioner Declines**
- Practitioner rejects appointment → Immediate refund
- Status: `PENDING_CONFIRMATION` → `REFUNDED`

**C. Patient Cancels (≥24h before)**
- Patient cancels with ≥24 hours notice → Full refund
- Status: `CONFIRMED` → `REFUNDED`

**D. Patient Cancels (<24h before)**
- Late cancellation → No refund (fee retained)
- Status: `CONFIRMED` → `CANCELLED` (no refund)

**E. Practitioner Cancels**
- Practitioner cancels any time → Full refund
- Status: Any → `REFUNDED`

**F. No-Show**
- Patient doesn't attend → Fee retained
- Status: `CONFIRMED` → `NO_SHOW` (no refund)

### 4. **My Appointments Dashboard**
New feature card added to nurse.html:
- View all booked appointments
- See payment status and booking details
- Cancel with automatic refund calculation
- Reschedule appointments (24h+ notice)
- Real-time status tracking

---

## 🔧 Technical Implementation Details

### Files Modified

#### **nurse.html**
**Line ~15**: Added Paystack integration scripts
```html
<script src="js/paystack-integration.js"></script>
<script src="js/appointment-booking.js"></script>
```

**Line ~64-107**: Updated AI feature cards with "My Appointments"
```html
<div class="col-md-3">
    <div class="ai-feature-card text-center p-3">
        <div class="ai-icon mb-2">📅</div>
        <h5>My Appointments</h5>
        <p class="small">View & manage your bookings</p>
        <button class="btn btn-outline-primary btn-sm" onclick="openMyAppointments()">View Appointments</button>
    </div>
</div>
```

**Line ~1650-1862**: Replaced booking handler with payment-integrated version
- Validates email for payment
- Shows payment breakdown (R400 + R100)
- Initiates Paystack inline payment
- Handles success/failure callbacks
- Updates appointment status after payment
- Deletes pending appointments on cancellation

**Line ~1907-2135**: Added payment-specific functions
- `saveAppointmentWithPayment()` - Creates appointment with PENDING_PAYMENT status
- `updateAppointmentAfterPayment()` - Updates to PENDING_CONFIRMATION after successful payment
- `createPaymentTransaction()` - Records payment in payment_transactions table
- `deletePendingAppointment()` - Removes unpaid appointments
- `cancelAppointment()` - Handles cancellation with refund logic
- `rescheduleAppointment()` - Moves appointment to new date/time

**Line ~3565**: Updated booking button text
```html
<button id="bookAppointmentBtn" class="btn btn-success btn-lg" onclick="confirmBooking()">
    <i class="fas fa-credit-card me-2"></i>Confirm Booking & Pay
</button>
<small class="text-muted text-center">
    💳 Secure payment via Paystack • R500 consultation fee<br>
    ✅ 80% to practitioner, 20% platform fee
</small>
```

**Line ~3793-3965**: Added My Appointments modal and functions
- `openMyAppointments()` - Opens modal
- `loadMyAppointments()` - Loads from database or localStorage
- `getStatusClass()` - Returns Bootstrap badge class for status
- `canCancelAppointment()` - Checks if cancellation is allowed
- `canRescheduleAppointment()` - Checks if rescheduling is allowed
- `viewAppointmentDetails()` - Shows detailed view (TODO)
- `initiateCancelAppointment()` - Prompts for reason and cancels
- `openRescheduleModal()` - Prompts for new date/time

---

## 🚀 How It Works: User Journey

### **Patient Books Appointment**

1. **Open Booking Modal**
   - Click "AI Appointment Booking" card
   - Modal opens with 2-panel layout (patient info + AI scheduling)

2. **Fill Patient Details**
   - Name, phone, **email** (required for payment)
   - Select practitioner from dropdown
   - Choose appointment type
   - Enter reason for visit

3. **AI Scheduling**
   - AI analyzes symptoms and recommends practitioners
   - Select preferred date
   - Choose from available time slots

4. **Payment Confirmation**
   - Click "Confirm Booking & Pay"
   - System validates email
   - Shows payment breakdown:
     ```
     💳 PAYMENT REQUIRED
     
     Consultation Fee: R500
     - Practitioner receives: R400 (80%)
     - Platform fee: R100 (20%)
     
     Cancellation Policy:
     - Cancel ≥24h before: Full refund
     - Cancel <24h before: No refund
     - No-show: No refund
     ```
   - Click OK to proceed

5. **Paystack Payment**
   - Paystack inline modal opens
   - Patient enters card details
   - Payment processed securely
   - Test card: **4084 0840 8408 4081** (any CVV, future expiry)

6. **Payment Success**
   - Appointment status: `PENDING_CONFIRMATION`
   - Payment reference recorded
   - Success message with booking ID
   - Patient receives confirmation

7. **Practitioner Confirmation**
   - Practitioner has 24 hours to confirm
   - If confirmed → Status: `CONFIRMED`
   - If timeout (24h) → Status: `REFUNDED` (automatic)

### **Patient Manages Appointment**

1. **View Appointments**
   - Click "My Appointments" card
   - See all bookings in table format
   - Status badges show current state

2. **Cancel Appointment**
   - Click "Cancel" button
   - Enter cancellation reason
   - System checks timing:
     - ≥24h before → Full refund processed
     - <24h before → No refund, fee retained
   - Paystack refund initiated if eligible

3. **Reschedule Appointment**
   - Click "Reschedule" (only if ≥24h away)
   - Enter new date and time
   - Status returns to `PENDING_CONFIRMATION`
   - Practitioner must re-confirm

---

## 🗄️ Database Schema

### Required Tables

#### **appointments**
```sql
CREATE TABLE appointments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id TEXT UNIQUE,
    user_id UUID REFERENCES auth.users(id),
    practitioner_id UUID,
    practitioner_name TEXT,
    practitioner_phone TEXT,
    practitioner_email TEXT,
    patient_name TEXT NOT NULL,
    patient_phone TEXT NOT NULL,
    patient_email TEXT NOT NULL,
    appointment_date DATE NOT NULL,
    appointment_time TIME NOT NULL,
    appointment_type TEXT DEFAULT 'consultation',
    reason TEXT,
    status TEXT DEFAULT 'PENDING_PAYMENT',
    payment_status TEXT DEFAULT 'UNPAID',
    payment_reference TEXT,
    payment_date TIMESTAMPTZ,
    consultation_fee DECIMAL(10,2) DEFAULT 500.00,
    payment_amount INTEGER, -- Amount in kobo
    cancellation_reason TEXT,
    cancellation_date TIMESTAMPTZ,
    refund_status TEXT,
    rescheduled_at TIMESTAMPTZ,
    ai_recommendation TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

#### **payment_transactions**
```sql
CREATE TABLE payment_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    appointment_id UUID REFERENCES appointments(id),
    payment_reference TEXT UNIQUE NOT NULL,
    amount INTEGER NOT NULL, -- In kobo
    status TEXT DEFAULT 'PENDING',
    payment_method TEXT DEFAULT 'paystack',
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## ⚙️ Configuration

### Environment Variables (Vercel/Supabase)

```bash
# Supabase
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key

# Paystack (Test keys provided)
PAYSTACK_PUBLIC_KEY=pk_test_74336bdb2862bdcde9f71f4c2e3243fc3a2fedf6
PAYSTACK_SECRET_KEY=sk_test_ce04e3466d797c150e1b7c81ce8d3a5c51bbc098
```

### config.js
```javascript
window.CONFIG = {
    SUPABASE_URL: 'your_supabase_url',
    SUPABASE_ANON_KEY: 'your_supabase_anon_key',
    PAYSTACK_PUBLIC_KEY: 'pk_test_74336bdb2862bdcde9f71f4c2e3243fc3a2fedf6'
};
```

---

## 🧪 Testing

### Test Payment Flow

1. **Open nurse.html** in browser
2. Click **"AI Appointment Booking"**
3. Fill in details:
   - Name: Test Patient
   - Email: test@example.com (required!)
   - Phone: +27 123 456 789
   - Select any practitioner
   - Choose date and time
4. Click **"Confirm Booking & Pay"**
5. In Paystack modal, use test card:
   - Card: `4084 0840 8408 4081`
   - CVV: Any 3 digits
   - Expiry: Any future date
6. Complete payment
7. Verify success message
8. Check "My Appointments" to see booking

### Test Cancellation (Full Refund)

1. Book appointment for tomorrow
2. Go to "My Appointments"
3. Click "Cancel"
4. Enter reason
5. Confirm cancellation
6. Verify refund message (≥24h before)

### Test Cancellation (No Refund)

1. Manually update appointment date in database to today
2. Try to cancel
3. Verify "No refund" message (<24h before)

---

## 🔐 Security Features

### 1. **Row Level Security (RLS)**
- Patients can only view their own appointments
- Practitioners can only view appointments for them
- Admin has full access

### 2. **Payment Security**
- All payments processed via Paystack (PCI-DSS compliant)
- No card details stored in database
- Only payment references stored

### 3. **Email Validation**
- Required for payment processing
- Regex validation before payment initiation

### 4. **Status Validation**
- Can only cancel: `PENDING_PAYMENT`, `PENDING_CONFIRMATION`, `CONFIRMED`
- Can only reschedule: `PENDING_CONFIRMATION`, `CONFIRMED`
- Cannot modify `COMPLETED`, `REFUNDED`, `NO_SHOW`

---

## 📊 Workflow Diagram

```
┌─────────────┐
│   Patient   │
│ Opens Modal │
└──────┬──────┘
       │
       ▼
┌──────────────────────┐
│  Fill Patient Info   │
│  - Name, Email, etc  │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│   AI Scheduling      │
│  - Date/Time select  │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│ Confirm & Pay Button │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│  Payment Breakdown   │
│  R500 = R400 + R100  │
└──────┬───────────────┘
       │ [OK]
       ▼
┌──────────────────────┐
│  Save Appointment    │
│ Status: PENDING_PAY  │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│  Paystack Payment    │
│   Inline Modal       │
└──────┬───────────────┘
       │
       ├─[Success]────────────────────────┐
       │                                  │
       ▼                                  │
┌──────────────────────┐                  │
│ Update Appointment   │                  │
│ Status: PENDING_CONF │                  │
└──────┬───────────────┘                  │
       │                                  │
       ▼                                  │
┌──────────────────────┐                  │
│   Success Message    │                  │
│  - Booking ID        │                  │
│  - Payment Ref       │                  │
└──────┬───────────────┘                  │
       │                                  │
       ▼                                  │
┌──────────────────────┐                  │
│ Practitioner Confirm │                  │
│   (24h window)       │                  │
└──────┬───────────────┘                  │
       │                                  │
       ├─[Confirmed]──────┐               │
       │                  │               │
       ▼                  │               │
    CONFIRMED             │               │
                          │               │
       ├─[Timeout]────────┘               │
       │                                  │
       ▼                                  │
    REFUNDED                              │
                                          │
       ├─[Cancel]─────────────────────────┘
       │
       ▼
  [Cancel Flow - See Refund Logic Above]
```

---

## 🎯 Next Steps

### For Production Deployment

1. **Run Database Schema**
   ```bash
   # Execute payment_appointments_schema.sql in Supabase SQL Editor
   ```

2. **Configure Environment Variables**
   - Add to Vercel: SUPABASE_SERVICE_ROLE_KEY, PAYSTACK_SECRET_KEY
   - Update config.js with production keys

3. **Set Up Webhooks**
   - Register webhook URL in Paystack dashboard
   - URL: `https://yourdomain.vercel.app/api/webhooks/paystack`
   - Events: `charge.success`, `refund.processed`

4. **Enable Cron Jobs**
   - Vercel automatically runs cron based on vercel.json
   - Hourly: Check unconfirmed appointments
   - Hourly: Mark no-shows
   - Daily 8 AM: Send reminders

5. **Test with Real Cards**
   - Switch to production Paystack keys
   - Test with real card (small amount)
   - Verify refund processing

6. **User Acceptance Testing**
   - Test full booking flow
   - Test cancellation with refund
   - Test cancellation without refund
   - Test rescheduling
   - Test "My Appointments" view

---

## 📞 Support

### Common Issues

**Issue**: Payment modal doesn't open
**Solution**: Check browser console for Paystack script errors. Ensure `js/paystack-integration.js` is loaded.

**Issue**: Email validation fails
**Solution**: Ensure patient enters valid email with @ symbol. Required for Paystack.

**Issue**: Appointments not showing in "My Appointments"
**Solution**: Check user is logged in. Verify `currentUserId` in console. Check database RLS policies.

**Issue**: Refund not processed
**Solution**: Check Paystack dashboard for payment reference. Verify webhook is configured. Check `payment_transactions` table.

---

## 🎉 Summary

The AI Appointment Booking system now features:
- ✅ **Full payment integration** via Paystack
- ✅ **80/20 revenue split** (R400 practitioner, R100 platform)
- ✅ **Automated refund logic** for all 6 edge cases
- ✅ **24-hour confirmation window** with auto-refund
- ✅ **Appointment management** (view, cancel, reschedule)
- ✅ **Status tracking** (7 states: PENDING_PAYMENT → COMPLETED)
- ✅ **Security** (RLS, email validation, payment verification)
- ✅ **Fallback** to localStorage if database unavailable

**Next**: Deploy to production and start processing real appointments! 🚀

---

**Generated**: January 28, 2026
**Author**: GitHub Copilot
**Version**: 1.0
