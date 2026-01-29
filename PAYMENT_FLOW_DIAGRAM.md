# PAYMENT FLOW DIAGRAM

## 💰 New Payment Structure (With Paystack Fees Added On Top)

```
┌─────────────────────────────────────────────────────────────────┐
│                    PATIENT BOOKS APPOINTMENT                     │
│                                                                   │
│  Selected Practitioner: Dr. Johnson                              │
│  Consultation Fee (set by practitioner): R3455                   │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                   SYSTEM CALCULATES FEES                         │
│                                                                   │
│  1. Consultation Fee:        R3455                               │
│     ├─ Practitioner (80%):   R2764                               │
│     └─ Platform (20%):       R691                                │
│                                                                   │
│  2. Paystack Fee (ZAR):      R50                                 │
│     Formula: (3455 * 0.015) + 1 = 52.825 → 53 → CAPPED at R50   │
│                                                                   │
│  3. TOTAL TO CHARGE:         R3505 (R3455 + R50)                 │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                  PATIENT SEES BREAKDOWN                          │
│                                                                   │
│  💳 PAYMENT REQUIRED                                             │
│                                                                   │
│  TOTAL AMOUNT: 3505 ZAR                                          │
│                                                                   │
│  Breakdown:                                                      │
│  • Consultation Fee: 3455 ZAR                                    │
│  • Processing Fee: 50 ZAR                                        │
│    - Practitioner receives: 2764 ZAR (80%)                       │
│    - Platform fee: 691 ZAR (20%)                                 │
│                                                                   │
│  ℹ️ The total amount includes secure payment processing          │
│     and platform service fees.                                   │
│                                                                   │
│  [ Cancel ]  [ OK - Proceed to Payment ]                         │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                   PAYSTACK PAYMENT POPUP                         │
│                                                                   │
│  Amount: 350500 kobo (R3505 * 100)                               │
│  Patient pays: R3505                                             │
│                                                                   │
│  [Credit Card] [Bank] [Mobile Money]                             │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    PAYMENT SUCCESSFUL                            │
│                                                                   │
│  ✅ PAYMENT SUCCESSFUL! Appointment Booked!                      │
│                                                                   │
│  Total Paid: 3505 ZAR                                            │
│                                                                   │
│  Payment Breakdown:                                              │
│  • Consultation Fee: 3455 ZAR                                    │
│    - Practitioner receives: 2764 ZAR (80%)                       │
│    - Platform fee: 691 ZAR (20%)                                 │
│  • Processing Fee: 50 ZAR                                        │
│                                                                   │
│  ℹ️ The total amount includes secure payment processing          │
│     and platform service fees.                                   │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                  DATABASE STORES DETAILS                         │
│                                                                   │
│  booking_id:         APT_1234567890                              │
│  consultation_fee:   3455.00                                     │
│  paystack_fee:       50.00                                       │
│  total_amount:       3505.00                                     │
│  currency:           ZAR                                         │
│  status:             PENDING_CONFIRMATION                        │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                  MONEY DISTRIBUTION                              │
│                                                                   │
│  PATIENT PAID: R3505                                             │
│                                                                   │
│  ┌──────────────────────────────────────┐                        │
│  │  Consultation Fee: R3455             │                        │
│  │  ├─► Practitioner: R2764 (80%)       │                        │
│  │  └─► Platform: R691 (20%)            │                        │
│  └──────────────────────────────────────┘                        │
│                                                                   │
│  ┌──────────────────────────────────────┐                        │
│  │  Processing Fee: R50                 │                        │
│  │  └─► Paystack                        │                        │
│  └──────────────────────────────────────┘                        │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📊 COMPARISON: Before vs After

### BEFORE (Fees deducted from consultation)
```
Patient pays:            R3455
                           │
                ┌──────────┴──────────┐
                ↓                     ↓
    Consultation: R3455    Paystack: ~R50 (deducted)
    ├─ Practitioner: R2722 (79%)
    ├─ Platform: R683 (19.8%)
    └─ Paystack: R50 (1.4%)

❌ Problems:
- Split is messy (not clean 80/20)
- Practitioner loses money to processing
- Complex accounting
```

### AFTER (Fees added on top) ✅
```
Patient pays:            R3505
                           │
                ┌──────────┴──────────┐
                ↓                     ↓
    Consultation: R3455     Processing: R50
    ├─ Practitioner: R2764 (80%)      └─► Paystack
    └─ Platform: R691 (20%)

✅ Benefits:
- Clean 80/20 split ALWAYS
- Practitioner gets full 80%
- Simple accounting
- Transparent pricing
```

---

## 🔄 REFUND FLOW

### Full Refund Scenario (Cancel ≥24h before)

```
┌─────────────────────────────────────────────────────────────────┐
│                 PATIENT CANCELS APPOINTMENT                      │
│                                                                   │
│  Cancel Appointment?                                             │
│                                                                   │
│  Appointment: Dr. Johnson                                        │
│  Date: February 15, 2026 at 10:00 AM                             │
│                                                                   │
│  Refund Policy:                                                  │
│  ✅ Full refund (3505 ZAR) - cancelled ≥24h before               │
│     • Consultation: 3455 ZAR                                     │
│     • Processing: 50 ZAR                                         │
│                                                                   │
│  Reason: Schedule conflict                                       │
│                                                                   │
│  [ No ]  [ Yes - Cancel and Refund ]                             │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│              PAYSTACK REFUND API CALLED                          │
│                                                                   │
│  Refund Amount: 350500 kobo (R3505 * 100)                        │
│  Reference: PAY_APT_1234567890_1738056789123                     │
│  Reason: "Appointment cancelled by patient: Schedule conflict"   │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    REFUND CONFIRMATION                           │
│                                                                   │
│  ✅ Appointment Cancelled                                        │
│                                                                   │
│  A refund of 3505 ZAR will be processed within 5-7 business days │
│    • Consultation: 3455 ZAR                                      │
│    • Processing: 50 ZAR                                          │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                   DATABASE UPDATED                               │
│                                                                   │
│  status:            CANCELLED                                    │
│  refund_status:     PENDING                                      │
│  refund_amount:     3505.00                                      │
│  cancellation_date: 2026-01-28T14:30:00Z                         │
└─────────────────────────────────────────────────────────────────┘
```

### No Refund Scenario (Cancel <24h before)

```
┌─────────────────────────────────────────────────────────────────┐
│                 PATIENT CANCELS (TOO LATE)                       │
│                                                                   │
│  Cancel Appointment?                                             │
│                                                                   │
│  Appointment: Dr. Johnson                                        │
│  Date: February 15, 2026 at 10:00 AM                             │
│                                                                   │
│  Refund Policy:                                                  │
│  ❌ No refund - cancelled <24h before appointment                │
│                                                                   │
│  Reason: Emergency                                               │
│                                                                   │
│  [ No ]  [ Yes - Cancel (No Refund) ]                            │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    CANCELLATION CONFIRMED                        │
│                                                                   │
│  ✅ Appointment Cancelled                                        │
│                                                                   │
│  No refund will be issued (cancelled <24h before appointment)    │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🌍 MULTI-CURRENCY EXAMPLES

### South Africa (ZAR)
```
Consultation:   R3455
Paystack:       R50 (1.5% + R1, capped at R50)
──────────────────────
TOTAL:          R3505

Split:
├─ Practitioner: R2764 (80% of R3455)
├─ Platform:     R691 (20% of R3455)
└─ Paystack:     R50
```

### Nigeria (NGN)
```
Consultation:   ₦50,000
Paystack:       ₦850 (1.5% + ₦100 = 750 + 100)
──────────────────────
TOTAL:          ₦50,850

Split:
├─ Practitioner: ₦40,000 (80% of ₦50,000)
├─ Platform:     ₦10,000 (20% of ₦50,000)
└─ Paystack:     ₦850
```

### Kenya (KES)
```
Consultation:   KSh5,000
Paystack:       KSh80 (1.5% + KSh5 = 75 + 5)
──────────────────────
TOTAL:          KSh5,080

Split:
├─ Practitioner: KSh4,000 (80%)
├─ Platform:     KSh1,000 (20%)
└─ Paystack:     KSh80
```

### USA (USD)
```
Consultation:   $250
Paystack:       $9.85 (3.9% + $0.10 = 9.75 + 0.10)
──────────────────────
TOTAL:          $259.85

Split:
├─ Practitioner: $200 (80%)
├─ Platform:     $50 (20%)
└─ Paystack:     $9.85
```

---

## 📱 USER JOURNEY MAP

```
START: Patient wants to book appointment
  │
  ├─► 1. Browse Practitioners
  │   └─► See consultation fee (e.g., R3455)
  │
  ├─► 2. Select Practitioner
  │   └─► Modal shows:
  │       "Total: 3505 ZAR (incl. processing fees)"
  │       "Consultation: 3455 ZAR"
  │       "Processing: 50 ZAR"
  │
  ├─► 3. Fill Appointment Details
  │   └─► Name, Email, Date, Time, Reason
  │
  ├─► 4. Click "Confirm Booking"
  │   └─► Payment dialog appears with full breakdown
  │
  ├─► 5. Review Breakdown
  │   └─► "TOTAL AMOUNT: 3505 ZAR"
  │       "• Consultation: 3455"
  │       "• Processing: 50"
  │       "ℹ️ Includes secure payment processing..."
  │
  ├─► 6. Click "OK"
  │   └─► Paystack popup opens
  │
  ├─► 7. Complete Payment
  │   └─► Pay R3505 via card/bank/mobile money
  │
  ├─► 8. Success Message
  │   └─► "Total Paid: 3505 ZAR"
  │       Shows complete breakdown
  │
  ├─► 9. View in Dashboard
  │   └─► My Appointments shows "3505 ZAR"
  │       "Fee: 3455 + Processing: 50"
  │       "Split: 2764 + 691"
  │
  └─► 10. Cancel (if needed)
      └─► "Full refund (3505 ZAR)"
          "• Consultation: 3455"
          "• Processing: 50"

END: Patient understands all fees clearly
```

---

## 🎯 KEY PRINCIPLES

### 1. Transparency
```
✅ DO:
- Show total amount upfront
- Display complete breakdown
- Explain what each fee covers
- Use consistent UX message

❌ DON'T:
- Hide processing fees
- Show only consultation fee
- Use confusing language
- Change amounts mid-flow
```

### 2. Fairness
```
✅ DO:
- Keep 80/20 split sacred
- Add processing fees on top
- Refund everything patient paid
- Treat all currencies equally

❌ DON'T:
- Deduct fees from practitioner
- Change split percentages
- Partial refunds of total
- Favor certain currencies
```

### 3. Simplicity
```
✅ DO:
- Use clear formulas
- Round to nearest unit
- Apply currency-specific caps
- Store all amounts in DB

❌ DON'T:
- Use complex calculations
- Show decimal precision
- Ignore fee caps
- Rely on real-time calculation only
```

---

## 📐 FORMULAS REFERENCE

### Paystack Fee Calculation

#### ZAR (South Africa)
```javascript
paystackFee = Math.min(
    Math.round(consultationFee * 0.015) + 1,
    50
);

Example:
R500:   min(round(500 * 0.015) + 1, 50) = min(9, 50) = 9
R3455:  min(round(3455 * 0.015) + 1, 50) = min(53, 50) = 50
R5000:  min(round(5000 * 0.015) + 1, 50) = min(76, 50) = 50
```

#### NGN (Nigeria)
```javascript
paystackFee = Math.min(
    Math.round(consultationFee * 0.015) + 100,
    2000
);

Example:
₦1000:   min(round(1000 * 0.015) + 100, 2000) = min(115, 2000) = 115
₦50000:  min(round(50000 * 0.015) + 100, 2000) = min(850, 2000) = 850
₦200000: min(round(200000 * 0.015) + 100, 2000) = min(3100, 2000) = 2000
```

#### KES (Kenya)
```javascript
paystackFee = Math.round(consultationFee * 0.015) + 5;

Example:
KSh1000:  round(1000 * 0.015) + 5 = 15 + 5 = 20
KSh5000:  round(5000 * 0.015) + 5 = 75 + 5 = 80
```

#### GHS (Ghana)
```javascript
paystackFee = Math.round(consultationFee * 0.0195);

Example:
GH₵500:  round(500 * 0.0195) = round(9.75) = 10
GH₵1000: round(1000 * 0.0195) = round(19.5) = 20
```

#### USD/EUR (International)
```javascript
paystackFee = Math.round(consultationFee * 0.039 * 100) / 100;
if (currency === 'USD' || currency === 'EUR') {
    paystackFee += 0.10;
}

Example:
$100:  round(100 * 0.039 * 100) / 100 + 0.10 = 3.90 + 0.10 = 4.00
$250:  round(250 * 0.039 * 100) / 100 + 0.10 = 9.75 + 0.10 = 9.85
```

### 80/20 Split (Always from consultation fee only)
```javascript
practitionerAmount = Math.round(consultationFee * 0.8);
platformAmount = Math.round(consultationFee * 0.2);

Example:
R3455:
- Practitioner: round(3455 * 0.8) = round(2764) = 2764
- Platform: round(3455 * 0.2) = round(691) = 691
```

### Total Amount
```javascript
totalAmountToPay = consultationFee + paystackFee;

Example:
Consultation: R3455
Paystack: R50
Total: R3455 + R50 = R3505
```

---

## ✅ FINAL CHECKLIST

### System Verification
- [x] Fee calculation correct for all currencies
- [x] 80/20 split unaffected by processing fees
- [x] Total amount = consultation + processing
- [x] Database stores all three amounts
- [x] All displays show total consistently
- [x] UX message appears everywhere
- [x] Refunds include total amount
- [x] Console logs for debugging
- [x] Error handling in place
- [x] Multi-currency support complete

### Documentation
- [x] Implementation guide created
- [x] Testing guide created
- [x] Update summary created
- [x] Visual flow diagram created
- [x] SQL migration script created
- [x] Support team training material

### Ready for Production
- [ ] Database migration run
- [ ] File deployed to Vercel
- [ ] Test payment completed
- [ ] Database verified
- [ ] Support team trained
- [ ] Monitoring enabled

---

*Payment Flow Diagram v1.0 - Last Updated: 2026-01-28*
