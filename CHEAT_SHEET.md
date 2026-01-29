# 💳 Payment Integration Cheat Sheet

## 🎯 Quick Reference: AI Appointment Booking with Payment

---

### 🔑 Key Changes to nurse.html

| Section | Line Range | What Changed |
|---------|-----------|--------------|
| **Scripts** | ~15 | Added paystack-integration.js & appointment-booking.js |
| **UI Card** | ~100 | Added "My Appointments" feature card |
| **Booking Handler** | ~1650-1862 | Replaced with payment-integrated version |
| **Helper Functions** | ~1907-2135 | Added 6 payment-specific functions |
| **Modal** | ~3565 | Updated button to "Confirm Booking & Pay" |
| **My Appointments** | ~3793-3965 | Added modal + management functions |

---

### 💰 Payment Breakdown

**R500 Consultation Fee**
- R400 (80%) → Practitioner
- R100 (20%) → Platform

**Test Card**: `4084 0840 8408 4081`

---

### 📋 Appointment Statuses

| Status | Meaning | Can Cancel? | Can Reschedule? |
|--------|---------|-------------|-----------------|
| `PENDING_PAYMENT` | Created, not paid | Yes (Delete) | No |
| `PENDING_CONFIRMATION` | Paid, awaiting confirm | Yes (Refund) | No |
| `CONFIRMED` | Confirmed by practitioner | Yes (Check 24h) | Yes (if ≥24h) |
| `COMPLETED` | Appointment occurred | No | No |
| `CANCELLED` | Cancelled | N/A | No |
| `REFUNDED` | Payment refunded | N/A | No |
| `NO_SHOW` | Patient didn't attend | N/A | No |

---

### 💸 Refund Rules

| Scenario | Refund? | Status After |
|----------|---------|--------------|
| Unconfirmed 24h | ✅ R500 | `REFUNDED` |
| Practitioner declines | ✅ R500 | `REFUNDED` |
| Patient cancel ≥24h | ✅ R500 | `REFUNDED` |
| Patient cancel <24h | ❌ R0 | `CANCELLED` |
| Practitioner cancels | ✅ R500 | `REFUNDED` |
| Patient no-show | ❌ R0 | `NO_SHOW` |

---

### 🔧 Key Functions

#### **Booking Functions**
```javascript
saveAppointmentWithPayment(data)        // Create PENDING_PAYMENT
updateAppointmentAfterPayment(...)      // Update to PENDING_CONFIRMATION
createPaymentTransaction(...)           // Record payment
deletePendingAppointment(id)            // Remove unpaid
```

#### **Management Functions**
```javascript
cancelAppointment(id, reason)           // Cancel + refund logic
rescheduleAppointment(id, date, time)   // Move to new slot
openMyAppointments()                    // Open dashboard
loadMyAppointments()                    // Load from database
```

---

### 🧪 Testing Steps

1. ✅ Open nurse.html
2. ✅ Click "AI Appointment Booking"
3. ✅ Fill form (email required!)
4. ✅ Click "Confirm Booking & Pay"
5. ✅ Enter test card: 4084 0840 8408 4081
6. ✅ Verify success message
7. ✅ Click "My Appointments"
8. ✅ Test cancel/reschedule

---

### 🗄️ Database Tables

#### **appointments** (enhanced)
- `payment_status` TEXT
- `payment_reference` TEXT
- `payment_date` TIMESTAMPTZ
- `consultation_fee` DECIMAL
- `cancellation_reason` TEXT
- `refund_status` TEXT
- `rescheduled_at` TIMESTAMPTZ

#### **payment_transactions** (new)
- `id` UUID
- `appointment_id` UUID
- `payment_reference` TEXT
- `amount` INTEGER (kobo)
- `status` TEXT
- `payment_method` TEXT

---

### ⚙️ Environment Variables

```bash
SUPABASE_URL=your_url
SUPABASE_SERVICE_ROLE_KEY=your_key
PAYSTACK_PUBLIC_KEY=pk_test_74336bdb2862bdcde9f71f4c2e3243fc3a2fedf6
PAYSTACK_SECRET_KEY=sk_test_ce04e3466d797c150e1b7c81ce8d3a5c51bbc098
```

---

### 🎨 UI Elements Added

#### **Feature Card** (nurse.html)
```html
<div class="col-md-3">
    <div class="ai-feature-card text-center p-3">
        <div class="ai-icon mb-2">📅</div>
        <h5>My Appointments</h5>
        <button onclick="openMyAppointments()">View</button>
    </div>
</div>
```

#### **Booking Button** (modal)
```html
<button id="bookAppointmentBtn" onclick="confirmBooking()">
    <i class="fas fa-credit-card me-2"></i>Confirm Booking & Pay
</button>
<small>💳 Secure payment • R500 • 80/20 split</small>
```

---

### 🚨 Common Issues

| Issue | Solution |
|-------|----------|
| "Email validation fails" | Ensure email contains @ symbol |
| "Payment modal doesn't open" | Check Paystack script is loaded |
| "Appointments not showing" | Verify user is logged in |
| "Refund not processed" | Check Paystack webhook is configured |

---

### 📚 Documentation Files

1. **IMPLEMENTATION_COMPLETE.md** - Full summary
2. **AI_APPOINTMENT_PAYMENT_INTEGRATION.md** - Detailed guide
3. **QUICK_START_AI_PAYMENT.md** - Quick reference
4. **PAYMENT_WORKFLOW_DIAGRAMS.md** - Visual workflows

---

### 🎊 Deployment Checklist

- [ ] Run `payment_appointments_schema.sql`
- [ ] Configure Paystack webhook
- [ ] Add environment variables to Vercel
- [ ] Deploy to production
- [ ] Test with test card
- [ ] Switch to production Paystack keys
- [ ] Test with real card (small amount)
- [ ] Go live! 🚀

---

**Status**: ✅ COMPLETE
**Ready for**: Production deployment
**Next**: Run database schema and deploy
