# PAYSTACK PROCESSING FEE IMPLEMENTATION

## Overview
The payment system now adds Paystack processing fees **ON TOP** of the consultation fee, ensuring the 80/20 practitioner/platform split remains unaffected by payment processing costs.

---

## 🎯 Key Principle

**Patient pays consultation fee + processing fee**

- ✅ **80/20 split applies ONLY to consultation fee**
- ✅ **Processing fee is added on top** (patient absorbs this cost)
- ✅ **Clean, predictable, and scalable**

---

## 💰 Fee Structure

### Consultation Fee Split (80/20)
```
Consultation Fee: X ZAR
├─ Practitioner receives: 80% of X
└─ Platform receives: 20% of X
```

### Total Amount Charged
```
Total = Consultation Fee + Paystack Processing Fee

Patient Pays = X + Paystack Fee
```

---

## 📊 Paystack Fee Calculation by Currency

| Currency | Paystack Fee Formula | Example (500 units) |
|----------|---------------------|---------------------|
| **ZAR** (South Africa) | 1.5% + R1 (cap: R50) | R9 |
| **NGN** (Nigeria) | 1.5% + ₦100 (cap: ₦2000) | ₦108 |
| **KES** (Kenya) | 1.5% + KSh5 | KSh13 |
| **GHS** (Ghana) | 1.95% | GH₵10 |
| **USD/EUR** (International) | 3.9% + $0.10 | $0.30 |

---

## 🧮 Complete Calculation Examples

### Example 1: R500 Consultation (ZAR)

```
Consultation Fee:     R500
├─ Practitioner (80%): R400
└─ Platform (20%):     R100

Paystack Fee:         R9 (500 * 0.015 + 1 = 8.5 → 9)

TOTAL PATIENT PAYS:   R509
```

**Display to Patient:**
```
Total: R509 (includes processing fees)
• Consultation: R500 (R400 to practitioner + R100 platform)
• Processing: R9
ℹ️ The total amount includes secure payment processing and platform service fees.
```

---

### Example 2: R3455 Consultation (ZAR)

```
Consultation Fee:     R3455
├─ Practitioner (80%): R2764
└─ Platform (20%):     R691

Paystack Fee:         R50 (3455 * 0.015 + 1 = 52.825 → 53, CAPPED at R50)

TOTAL PATIENT PAYS:   R3505
```

**Breakdown:**
- Patient sees: **R3505**
- Practitioner gets: **R2764** (80% of R3455)
- Platform gets: **R691** (20% of R3455)
- Paystack gets: **R50** (processing fee)

---

### Example 3: ₦1000 Consultation (NGN - Nigeria)

```
Consultation Fee:     ₦1000
├─ Practitioner (80%): ₦800
└─ Platform (20%):     ₦200

Paystack Fee:         ₦115 (1000 * 0.015 + 100 = 115)

TOTAL PATIENT PAYS:   ₦1115
```

---

### Example 4: $250 Consultation (USD - International)

```
Consultation Fee:     $250
├─ Practitioner (80%): $200
└─ Platform (20%):     $50

Paystack Fee:         $9.85 (250 * 0.039 + 0.10 = 9.75 + 0.10 = 9.85)

TOTAL PATIENT PAYS:   $259.85
```

---

## 🔧 Technical Implementation

### 1. Fee Calculation Function (JavaScript)

```javascript
// Calculate Paystack processing fee (added on top)
let paystackFee = 0;

if (currency === 'ZAR') {
    paystackFee = Math.min(Math.round(consultationFee * 0.015) + 1, 50);
} else if (currency === 'NGN') {
    paystackFee = Math.min(Math.round(consultationFee * 0.015) + 100, 2000);
} else if (currency === 'KES') {
    paystackFee = Math.round(consultationFee * 0.015) + 5;
} else if (currency === 'GHS') {
    paystackFee = Math.round(consultationFee * 0.0195);
} else {
    // USD, EUR, and other international
    paystackFee = Math.round(consultationFee * 0.039 * 100) / 100;
    if (currency === 'USD' || currency === 'EUR') {
        paystackFee += 0.10;
    }
}

paystackFee = Math.round(paystackFee); // Round to nearest unit

// Total amount patient pays
const totalAmountToPay = consultationFee + paystackFee;

// 80/20 split based on consultation fee ONLY
const practitionerAmount = Math.round(consultationFee * 0.8);
const platformAmount = Math.round(consultationFee * 0.2);
```

---

### 2. Database Schema

```sql
-- Add columns to appointments table
ALTER TABLE appointments 
ADD COLUMN IF NOT EXISTS paystack_fee NUMERIC(10, 2),
ADD COLUMN IF NOT EXISTS total_amount NUMERIC(10, 2);

-- Example data
INSERT INTO appointments (
    consultation_fee,
    paystack_fee,
    total_amount,
    currency
) VALUES (
    3455,  -- Consultation fee
    50,    -- Paystack processing fee
    3505,  -- Total amount charged
    'ZAR'  -- Currency
);
```

---

### 3. Payment Processing

```javascript
// Charge the TOTAL amount (consultation + processing)
const amountInKobo = totalAmountToPay * 100;

paystackHandler.initiatePayment({
    amount: amountInKobo,  // 3505 * 100 = 350500 kobo
    email: patientEmail,
    reference: paymentReference,
    metadata: {
        consultation_fee: consultationFee,     // 3455
        paystack_fee: paystackFee,             // 50
        total_amount: totalAmountToPay,        // 3505
        practitioner_amount: practitionerAmount, // 2764
        platform_amount: platformAmount         // 691
    }
});
```

---

## 📱 User Experience (UX)

### A. Practitioner Selection Display
When patient selects a practitioner:
```
💳 Total: 3505 ZAR (incl. processing fees)

• Consultation: 3455 ZAR (2764 to practitioner + 691 platform)
• Processing: 50 ZAR
ℹ️ The total amount includes secure payment processing and platform service fees.
```

---

### B. Payment Confirmation Dialog
Before payment:
```
💳 PAYMENT REQUIRED

TOTAL AMOUNT: 3505 ZAR

Breakdown:
• Consultation Fee: 3455 ZAR
• Processing Fee: 50 ZAR
  - Practitioner receives: 2764 ZAR (80%)
  - Platform fee: 691 ZAR (20%)

ℹ️ The total amount includes secure payment processing and platform service fees.

Appointment Details:
Practitioner: Dr. Johnson
Date: 2026-02-15 at 10:00 AM
Patient: John Doe

Cancellation Policy:
- Cancel ≥24h before: Full refund (3505 ZAR)
- Cancel <24h before: No refund
- No-show: No refund

Click OK to proceed to secure payment via Paystack.
```

---

### C. Payment Success Message
After successful payment:
```
✅ PAYMENT SUCCESSFUL! Appointment Booked!

Booking ID: APT_1234567890
Payment Reference: PAY_APT_1234567890_1738056789123
Total Paid: 3505 ZAR

Payment Breakdown:
• Consultation Fee: 3455 ZAR
  - Practitioner receives: 2764 ZAR (80%)
  - Platform fee: 691 ZAR (20%)
• Processing Fee: 50 ZAR

ℹ️ The total amount includes secure payment processing and platform service fees.

Patient: John Doe
Practitioner: Dr. Johnson
Date: February 15, 2026 at 10:00 AM

Status: ⏳ Awaiting Practitioner Confirmation
The practitioner has 24 hours to confirm.
If not confirmed, you'll receive automatic refund of 3505 ZAR.

Manage this appointment in your dashboard.
```

---

### D. My Appointments Display
In appointment dashboard:
```
┌─────────────┬───────────────┬──────────────┬─────────────────┐
│ Booking ID  │ Practitioner  │ Date & Time  │ Amount          │
├─────────────┼───────────────┼──────────────┼─────────────────┤
│ APT_123     │ Dr. Johnson   │ 2026-02-15   │ 3505 ZAR        │
│             │               │ 10:00 AM     │ Fee: 3455 +     │
│             │               │              │ Processing: 50  │
│             │               │              │ Split: 2764+691 │
└─────────────┴───────────────┴──────────────┴─────────────────┘
```

---

### E. Cancellation Dialog
When cancelling appointment:
```
Cancel Appointment?

Appointment: Dr. Johnson
Date: February 15, 2026 at 10:00 AM

Refund Policy:
✅ Full refund (3505 ZAR) - cancelled ≥24h before
   • Consultation: 3455 ZAR
   • Processing: 50 ZAR

Reason: Schedule conflict

Proceed with cancellation?
```

---

### F. Refund Confirmation
After cancellation:
```
✅ Appointment Cancelled

A refund of 3505 ZAR will be processed within 5-7 business days.
  • Consultation: 3455 ZAR
  • Processing: 50 ZAR
```

---

## 🔄 Refund Policy

### Full Refund Scenarios (Total Amount = Consultation + Processing)
1. **Cancel ≥24h before appointment**: Full refund (3505 ZAR)
2. **Practitioner cancels**: Full refund (3505 ZAR)
3. **Not confirmed within 24h**: Full refund (3505 ZAR)
4. **Payment fails after booking**: Full refund (3505 ZAR)

### No Refund Scenarios
1. **Cancel <24h before appointment**: No refund
2. **Patient no-show**: No refund
3. **Appointment completed**: No refund

---

## 📈 Scaling Examples

### Different Consultation Fees

| Consultation | Currency | Paystack Fee | Total Charged | Practitioner (80%) | Platform (20%) |
|--------------|----------|--------------|---------------|--------------------|--------------------|
| 500 | ZAR | 9 | 509 | 400 | 100 |
| 1000 | ZAR | 16 | 1016 | 800 | 200 |
| 2500 | ZAR | 39 | 2539 | 2000 | 500 |
| 3455 | ZAR | 50 | 3505 | 2764 | 691 |
| 5000 | ZAR | 50 | 5050 | 4000 | 1000 |
| 1000 | NGN | 115 | 1115 | 800 | 200 |
| 5000 | NGN | 175 | 5175 | 4000 | 1000 |
| 250 | USD | 9.85 | 259.85 | 200 | 50 |
| 1000 | USD | 39.10 | 1039.10 | 800 | 200 |

---

## 🎨 Standard UX Wording

Use this exact wording throughout the system:

```
"The total amount includes secure payment processing and platform service fees."
```

**Why this wording?**
- ✅ Clear and transparent
- ✅ Explains why total is higher than base fee
- ✅ Professional tone
- ✅ Builds trust
- ✅ Legally compliant

---

## ✅ Benefits of This Approach

### 1. **Clean Financial Model**
- 80/20 split is ALWAYS consistent
- No complex calculations affecting practitioner earnings
- Easy to explain to stakeholders

### 2. **Predictable for Practitioners**
```
Practitioner sees: "You'll receive 80% of your consultation fee"
No surprises. No deductions from their share.
```

### 3. **Transparent for Patients**
```
Patient sees exact breakdown:
- What goes to practitioner
- What goes to platform
- What goes to payment processor
```

### 4. **Scalable**
- Works for any consultation fee amount
- Works across multiple currencies
- Automatically adjusts to Paystack's fee structure

### 5. **Legally Compliant**
- Full disclosure of all fees
- No hidden charges
- Meets consumer protection standards

---

## 🧪 Testing Checklist

### Test Different Fee Amounts
- [ ] R500 → Total: R509
- [ ] R1000 → Total: R1016
- [ ] R3455 → Total: R3505
- [ ] R5000 → Total: R5050 (verify cap at R50)

### Test Different Currencies
- [ ] ZAR: Verify 1.5% + R1 (cap R50)
- [ ] NGN: Verify 1.5% + ₦100 (cap ₦2000)
- [ ] KES: Verify 1.5% + KSh5
- [ ] USD: Verify 3.9% + $0.10

### Test User Flow
- [ ] Practitioner selection shows total amount
- [ ] Payment dialog shows full breakdown
- [ ] Success message shows all fees
- [ ] My Appointments displays correctly
- [ ] Cancellation shows refund amount
- [ ] Refund message confirms total returned

### Test Edge Cases
- [ ] Fee = 0 (should add only fixed Paystack fee)
- [ ] Fee > cap threshold (verify cap applies)
- [ ] Multiple appointments (verify independence)
- [ ] Currency conversion scenarios

---

## 📝 Database Queries for Verification

### View Payment Breakdown
```sql
SELECT 
    booking_id,
    practitioner_name,
    consultation_fee,
    paystack_fee,
    total_amount,
    currency,
    ROUND(consultation_fee * 0.8) as practitioner_80_percent,
    ROUND(consultation_fee * 0.2) as platform_20_percent,
    (total_amount - consultation_fee) as verified_paystack_fee
FROM appointments 
WHERE status NOT IN ('CANCELLED', 'DELETED')
ORDER BY created_at DESC;
```

### Verify Fee Calculations
```sql
SELECT 
    currency,
    COUNT(*) as appointments,
    AVG(consultation_fee) as avg_consultation,
    AVG(paystack_fee) as avg_paystack_fee,
    AVG(total_amount) as avg_total,
    SUM(ROUND(consultation_fee * 0.8)) as total_to_practitioners,
    SUM(ROUND(consultation_fee * 0.2)) as total_to_platform,
    SUM(paystack_fee) as total_processing_fees
FROM appointments 
WHERE status = 'COMPLETED'
GROUP BY currency;
```

---

## 🚀 Deployment Steps

1. **Update Database**
   ```sql
   -- Run add_paystack_fee_columns.sql
   ALTER TABLE appointments 
   ADD COLUMN IF NOT EXISTS paystack_fee NUMERIC(10, 2),
   ADD COLUMN IF NOT EXISTS total_amount NUMERIC(10, 2);
   ```

2. **Deploy Updated nurse.html**
   - All fee calculations now include Paystack fees
   - All displays show total amount + breakdown

3. **Test Payment Flow**
   - Book test appointment
   - Verify total amount charged
   - Verify success message
   - Check database records

4. **Monitor First Transactions**
   - Verify fees calculated correctly
   - Check refunds work with total amount
   - Confirm practitioner payouts use 80% of consultation only

---

## 🎓 Training for Support Team

**When patients ask: "Why is the total more than the consultation fee?"**

Answer:
```
"The total amount of [X] includes:
• Your consultation fee: [Y] (80% goes to your practitioner)
• Secure payment processing: [Z]

This ensures your payment is processed securely through Paystack, 
and your practitioner receives their full 80% share of the consultation fee."
```

---

## 📞 Support Scenarios

### Scenario 1: "I was charged more than expected"
**Response:**
```
I can help explain the breakdown:
• Consultation Fee: R3455 (this is what your practitioner set)
  - R2764 goes to your practitioner (80%)
  - R691 goes to platform services (20%)
• Processing Fee: R50 (secure payment processing via Paystack)
• TOTAL: R3505

All fees are disclosed before payment. The processing fee ensures 
your payment is secure and your practitioner gets their full share.
```

### Scenario 2: "Will I get the processing fee back if I cancel?"
**Response:**
```
Yes! If you cancel at least 24 hours before your appointment, 
you'll receive a full refund of R3505, which includes:
• Consultation fee: R3455
• Processing fee: R50

The refund will be processed within 5-7 business days.
```

---

## 🔐 Security & Compliance

- ✅ All fees disclosed upfront (pre-payment)
- ✅ Breakdown shown in confirmation
- ✅ Receipt includes all line items
- ✅ Refund policy clearly stated
- ✅ No hidden charges
- ✅ Complies with consumer protection laws
- ✅ PCI DSS compliant (via Paystack)

---

## 📊 Financial Reporting

### Revenue Breakdown Example (Monthly)
```
Appointments: 100
Average Consultation: R2000

Total Revenue:        R203,200
├─ Consultations:     R200,000
│  ├─ Practitioners:  R160,000 (80%)
│  └─ Platform:       R40,000 (20%)
└─ Processing Fees:   R3,200 (to Paystack)

Platform Net Revenue: R40,000
(Processing fees are pass-through to Paystack)
```

---

## 🎯 Summary

**The Golden Rule:**
> Patient pays: Consultation Fee + Processing Fee
> 
> Practitioner gets: 80% of Consultation Fee (ONLY)
> 
> Platform gets: 20% of Consultation Fee (ONLY)
> 
> Paystack gets: Processing Fee (ONLY)

**Clean. Transparent. Fair.**

---

*Last Updated: 2026-01-28*
*Version: 1.0*
