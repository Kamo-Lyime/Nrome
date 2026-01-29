# 📊 PAYMENT BOOKING WORKFLOW - VISUAL GUIDE

## Complete Appointment Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        PATIENT BOOKING JOURNEY                          │
└─────────────────────────────────────────────────────────────────────────┘

START: Patient visits nurse.html
   │
   ├──> Clicks "Book with Payment" button
   │
   ├──> Redirected to appointment-booking.html
   │
   │    ┌───────────────────────────────────────────┐
   │    │  STEP 1: SELECT PRACTITIONER & TIME       │
   │    ├───────────────────────────────────────────┤
   │    │  • Choose practitioner from dropdown      │
   │    │  • Select date (calendar)                 │
   │    │  • Select time slot                       │
   │    │  • Enter reason for visit                 │
   │    └───────────────────────────────────────────┘
   │
   ├──> Next: Patient Details
   │
   │    ┌───────────────────────────────────────────┐
   │    │  STEP 2: PATIENT DETAILS                  │
   │    ├───────────────────────────────────────────┤
   │    │  • Full name                              │
   │    │  • Phone number                           │
   │    │  • Email address                          │
   │    └───────────────────────────────────────────┘
   │
   ├──> Next: Payment
   │
   │    ┌───────────────────────────────────────────┐
   │    │  STEP 3: PAYMENT SUMMARY                  │
   │    ├───────────────────────────────────────────┤
   │    │  Consultation Fee:          R 500.00      │
   │    │  - Practitioner gets:       R 400 (80%)   │
   │    │  - Platform fee:            R 100 (20%)   │
   │    │                                            │
   │    │  Cancellation Policy:                     │
   │    │  • ≥24h before: Full refund               │
   │    │  • <24h before: No refund                 │
   │    └───────────────────────────────────────────┘
   │
   ├──> Clicks "Pay R500" button
   │
   ▼

┌─────────────────────────────────────────────────────────────────────────┐
│                      BACKEND PROCESSING STARTS                          │
└─────────────────────────────────────────────────────────────────────────┘

   │
   ├──> appointment-booking.js → createPendingAppointment()
   │
   │    • Generate unique booking_id (BK1738123456789)
   │    • Generate payment_reference (APT_1738123456_7890)
   │    • Calculate confirmation_deadline (NOW + 24 hours)
   │    • Calculate payment split (R400 + R100)
   │
   ├──> INSERT INTO appointments
   │    ┌───────────────────────────────────────────┐
   │    │  Database Record Created:                 │
   │    ├───────────────────────────────────────────┤
   │    │  status: PENDING_PAYMENT                  │
   │    │  payment_status: pending                  │
   │    │  amount_paid: 500                         │
   │    │  platform_fee: 100                        │
   │    │  practitioner_amount: 400                 │
   │    │  confirmation_deadline: 2026-01-29 12:00  │
   │    └───────────────────────────────────────────┘
   │
   ├──> appointment_logs → INSERT
   │    • action: 'appointment_created'
   │    • actor: 'patient'
   │
   ▼

┌─────────────────────────────────────────────────────────────────────────┐
│                      PAYSTACK PAYMENT FLOW                              │
└─────────────────────────────────────────────────────────────────────────┘

   │
   ├──> paystack-integration.js → initiatePayment()
   │
   ├──> PaystackPop.setup() called
   │
   ├──> Paystack Inline Modal Opens
   │    ┌───────────────────────────────────────────┐
   │    │  PAYSTACK PAYMENT MODAL                   │
   │    ├───────────────────────────────────────────┤
   │    │  Amount: R 500.00                         │
   │    │  Reference: APT_1738123456_7890           │
   │    │                                            │
   │    │  [Card Number]                            │
   │    │  [Expiry] [CVV]                           │
   │    │  [PIN]                                     │
   │    │                                            │
   │    │  [Pay Now] [Cancel]                       │
   │    └───────────────────────────────────────────┘
   │
   ├──> Patient enters card details
   │
   ├──> Paystack processes payment
   │
   ├──> PAYMENT SUCCESSFUL
   │
   ├──> Callback: onSuccess(response)
   │
   ▼

┌─────────────────────────────────────────────────────────────────────────┐
│                    PAYMENT SUCCESS HANDLING                             │
└─────────────────────────────────────────────────────────────────────────┘

   │
   ├──> appointment-booking.js → updateAppointmentAfterPayment()
   │
   ├──> paystack-integration.js → verifyPayment(reference)
   │    • Call Paystack API: /transaction/verify/:reference
   │    • Confirm payment status = success
   │
   ├──> UPDATE appointments
   │    ┌───────────────────────────────────────────┐
   │    │  Database Updated:                        │
   │    ├───────────────────────────────────────────┤
   │    │  status: PENDING_CONFIRMATION ✅          │
   │    │  payment_status: success ✅               │
   │    │  payment_metadata: {Paystack data}        │
   │    └───────────────────────────────────────────┘
   │
   ├──> INSERT INTO payment_transactions
   │    • reference: APT_1738123456_7890
   │    • transaction_type: 'payment'
   │    • amount: 500
   │    • status: 'success'
   │
   ├──> INSERT INTO appointment_logs
   │    • action: 'payment_successful'
   │    • actor: 'system'
   │
   ├──> INSERT INTO practitioner_notifications
   │    • notification_type: 'new_appointment'
   │    • message: "New appointment - Please confirm within 24h"
   │
   ▼

┌─────────────────────────────────────────────────────────────────────────┐
│                    WEBHOOK CONFIRMATION (Async)                         │
└─────────────────────────────────────────────────────────────────────────┘

   │ (Happens in parallel)
   │
   ├──> Paystack sends webhook to /api/webhooks/paystack
   │
   ├──> Event: charge.success
   │
   ├──> Verify signature (HMAC SHA512)
   │
   ├──> Find appointment by payment_reference
   │
   ├──> UPDATE appointments (confirm payment status)
   │
   ├──> Record webhook in payment_transactions
   │
   ▼

┌─────────────────────────────────────────────────────────────────────────┐
│                    SUCCESS SCREEN SHOWN                                 │
└─────────────────────────────────────────────────────────────────────────┘

   │
   ├──> Show Step 4: Confirmation
   │    ┌───────────────────────────────────────────┐
   │    │  ✓ Payment Successful!                    │
   │    ├───────────────────────────────────────────┤
   │    │  Booking Reference: BK1738123456789       │
   │    │  Practitioner: Dr. Test                   │
   │    │  Date: 2026-01-29 @ 10:00 AM              │
   │    │  Amount Paid: R 500.00                    │
   │    │  Status: PENDING_CONFIRMATION             │
   │    │                                            │
   │    │  Next Steps:                              │
   │    │  1. Practitioner will confirm in 24h      │
   │    │  2. You'll receive notification           │
   │    │  3. Auto-refund if not confirmed          │
   │    │                                            │
   │    │  [View My Appointments] [Book Another]    │
   │    └───────────────────────────────────────────┘
   │
   ▼

═══════════════════════════════════════════════════════════════════════════
                    AUTOMATED WORKFLOWS (Background)
═══════════════════════════════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────────────────────┐
│   WORKFLOW A: PRACTITIONER CONFIRMATION (Happy Path)                    │
└─────────────────────────────────────────────────────────────────────────┘

   Within 24 hours:
   │
   ├──> Practitioner logs into dashboard
   │
   ├──> Sees notification: "New appointment from Patient X"
   │
   ├──> Clicks "Confirm Appointment"
   │
   ├──> appointment-booking.js → confirmAppointment()
   │
   ├──> UPDATE appointments
   │    • status: CONFIRMED ✅
   │    • confirmed_at: NOW
   │
   ├──> INSERT INTO appointment_logs
   │    • action: 'practitioner_confirmed'
   │
   ├──> Notify patient via email/SMS
   │    "Your appointment is confirmed!"
   │
   ├──> Appointment occurs on scheduled date
   │
   ├──> Mark as COMPLETED
   │
   ├──> Practitioner receives payout (R400) via Paystack split
   │
   END: SUCCESS ✅


┌─────────────────────────────────────────────────────────────────────────┐
│   WORKFLOW B: UNCONFIRMED TIMEOUT (Auto-Refund)                        │
└─────────────────────────────────────────────────────────────────────────┘

   After 24 hours (no practitioner response):
   │
   ├──> CRON JOB runs: /api/cron/check-confirmations (hourly)
   │
   ├──> Query: SELECT * FROM appointments 
   │           WHERE status = 'PENDING_CONFIRMATION'
   │           AND confirmation_deadline < NOW()
   │
   ├──> Found 1 overdue appointment
   │
   ├──> FOR EACH overdue:
   │
   ├────> Call Paystack Refund API
   │      • POST /refund
   │      • transaction: APT_1738123456_7890
   │      • amount: 50000 (kobo = R500)
   │      • reason: "Practitioner did not confirm within 24h"
   │
   ├────> Paystack processes refund
   │
   ├────> UPDATE appointments
   │      ┌───────────────────────────────────────┐
   │      │  status: REFUNDED ✅                  │
   │      │  payment_status: refunded             │
   │      │  refund_reference: RF123456           │
   │      │  refunded_at: NOW                     │
   │      └───────────────────────────────────────┘
   │
   ├────> INSERT INTO payment_transactions
   │      • transaction_type: 'refund'
   │      • amount: 500
   │      • status: 'success'
   │
   ├────> INSERT INTO appointment_logs
   │      • action: 'auto_refund_unconfirmed'
   │      • actor: 'system'
   │
   ├────> Notify patient
   │      "Your R500 has been refunded - practitioner did not confirm"
   │
   END: REFUNDED ✅


┌─────────────────────────────────────────────────────────────────────────┐
│   WORKFLOW C: PATIENT CANCELLATION (≥24h before)                       │
└─────────────────────────────────────────────────────────────────────────┘

   Patient clicks "Cancel Appointment" in UI:
   │
   ├──> Check: appointment_date - NOW >= 24 hours?
   │
   ├──> YES → Full refund eligible
   │
   ├──> appointment-booking.js → handlePatientCancellation()
   │
   ├──> Call Paystack Refund API (R500)
   │
   ├──> UPDATE appointments
   │    • status: REFUNDED
   │    • cancelled_by: 'patient'
   │    • cancellation_reason: "Patient cancelled 48h before"
   │
   ├──> Notify practitioner
   │    "Appointment cancelled by patient - refund issued"
   │
   END: FULL REFUND ✅


┌─────────────────────────────────────────────────────────────────────────┐
│   WORKFLOW D: PATIENT CANCELLATION (<24h before)                       │
└─────────────────────────────────────────────────────────────────────────┘

   Patient tries to cancel 12 hours before:
   │
   ├──> Check: appointment_date - NOW < 24 hours?
   │
   ├──> YES → No refund (no-show policy)
   │
   ├──> UPDATE appointments
   │    • status: CANCELLED
   │    • cancelled_by: 'patient'
   │    • no_show_fee: 500 (full amount retained)
   │
   ├──> Show message to patient
   │    "Cancellation within 24h - no refund per policy"
   │
   ├──> Practitioner still receives payout (R400)
   │
   END: NO REFUND (Policy enforced) ⚠️


┌─────────────────────────────────────────────────────────────────────────┐
│   WORKFLOW E: PRACTITIONER CANCELLATION                                │
└─────────────────────────────────────────────────────────────────────────┘

   Practitioner cancels after confirming:
   │
   ├──> Practitioner clicks "Cancel Appointment"
   │
   ├──> appointment-booking.js → handlePractitionerCancellation()
   │
   ├──> Call Paystack Refund API (R500) - FULL REFUND regardless of timing
   │
   ├──> UPDATE appointments
   │    • status: REFUNDED
   │    • cancelled_by: 'practitioner'
   │
   ├──> Notify patient
   │    "Practitioner cancelled - full refund issued"
   │
   ├──> Optional: Issue goodwill credit
   │
   END: FULL REFUND + GOODWILL ✅


┌─────────────────────────────────────────────────────────────────────────┐
│   WORKFLOW F: NO-SHOW DETECTION                                        │
└─────────────────────────────────────────────────────────────────────────┘

   After appointment time passes:
   │
   ├──> CRON JOB runs: /api/cron/check-no-shows (hourly)
   │
   ├──> Query: SELECT * FROM appointments
   │           WHERE status = 'CONFIRMED'
   │           AND appointment_date + appointment_time < NOW()
   │           AND no_show_checked = false
   │
   ├──> Found appointments past their time
   │
   ├──> FOR EACH past appointment:
   │
   ├────> UPDATE appointments
   │      • status: NO_SHOW ⚠️
   │      • no_show_checked: true
   │      • no_show_fee: 500
   │
   ├────> Notify practitioner
   │      "Appointment marked NO_SHOW - update if patient attended"
   │
   ├────> Practitioner can override if patient actually attended
   │
   END: NO_SHOW MARKED ⚠️


═══════════════════════════════════════════════════════════════════════════
                         DATABASE STATE DIAGRAM
═══════════════════════════════════════════════════════════════════════════

appointments.status transitions:

    PENDING_PAYMENT
         │
         │ (Payment succeeds)
         ▼
    PENDING_CONFIRMATION
         │
         ├──> (24h timeout) ──────> REFUNDED
         │
         ├──> (Practitioner confirms)
         │         │
         │         ▼
         │    CONFIRMED
         │         │
         │         ├──> (Appointment occurs) ──> COMPLETED
         │         │
         │         ├──> (No-show) ──────────> NO_SHOW
         │         │
         │         ├──> (Practitioner cancels) ──> REFUNDED
         │         │
         │         └──> (Patient cancels ≥24h) ──> REFUNDED
         │                   │
         │                   └──> (Patient cancels <24h) ──> CANCELLED
         │
         └──> (Practitioner declines) ──> REFUNDED


═══════════════════════════════════════════════════════════════════════════
                         MONEY FLOW DIAGRAM
═══════════════════════════════════════════════════════════════════════════

Patient pays R500 via Paystack:
    │
    ├──> Paystack receives R500
    │
    ├──> Paystack fee deducted (~R15)
    │
    ├──> Remaining R485 split:
    │    
    ├───> 80% to Practitioner Subaccount = R400 (goes to their bank)
    │     (Paystack automatically transfers to practitioner's bank)
    │
    └───> 20% to Platform Account = R100 (your revenue)
          (Paystack automatically transfers to your bank)


Refund scenario:
    │
    ├──> Refund initiated (R500)
    │
    ├──> Paystack reverses the split:
    │    
    ├───> R400 taken back from practitioner settlement
    │
    └───> R100 taken back from platform settlement
    │
    └──> Full R500 returned to patient's original payment method


═══════════════════════════════════════════════════════════════════════════
                              THE END
═══════════════════════════════════════════════════════════════════════════

Every scenario is covered:
✅ Happy path (booking → payment → confirm → attend)
✅ Timeout refund (no confirmation)
✅ Patient cancels (early vs late)
✅ Practitioner cancels
✅ Practitioner declines
✅ No-show handling
✅ All logged in appointment_logs
✅ All financial transactions in payment_transactions
✅ Full audit trail for disputes
