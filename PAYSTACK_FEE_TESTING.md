# PAYSTACK FEE TESTING GUIDE

## Quick Test Scenarios

### Test 1: R500 Consultation (ZAR)
**Expected Results:**
- Consultation Fee: R500
- Paystack Fee: R9 (500 * 0.015 + 1 = 8.5 → 9)
- **Total Charged: R509**
- Practitioner receives: R400 (80% of R500)
- Platform receives: R100 (20% of R500)

**What to verify:**
1. Practitioner selection shows "Total: 509 ZAR (incl. processing fees)"
2. Payment dialog shows breakdown with R9 processing fee
3. Paystack charges 50900 kobo (R509 * 100)
4. Success message shows "Total Paid: 509 ZAR"
5. My Appointments shows "509 ZAR" with "Fee: 500 + Processing: 9"
6. Cancellation refund shows "Full refund (509 ZAR)"

---

### Test 2: R3455 Consultation (ZAR) - User's Example
**Expected Results:**
- Consultation Fee: R3455
- Paystack Fee: R50 (3455 * 0.015 + 1 = 52.825 → 53, CAPPED at R50)
- **Total Charged: R3505**
- Practitioner receives: R2764 (80% of R3455)
- Platform receives: R691 (20% of R3455)

**What to verify:**
1. Modal shows "Total: 3505 ZAR (incl. processing fees)"
2. Payment dialog shows "TOTAL AMOUNT: 3505 ZAR"
3. Paystack charges 350500 kobo
4. Success: "Total Paid: 3505 ZAR"
5. Dashboard: "3505 ZAR | Fee: 3455 + Processing: 50 | Split: 2764+691"
6. Cancel: "Full refund (3505 ZAR) • Consultation: 3455 ZAR • Processing: 50 ZAR"

---

### Test 3: ₦1000 Consultation (NGN - Nigeria)
**Expected Results:**
- Consultation Fee: ₦1000
- Paystack Fee: ₦115 (1000 * 0.015 + 100 = 115)
- **Total Charged: ₦1115**
- Practitioner receives: ₦800 (80%)
- Platform receives: ₦200 (20%)

**What to verify:**
1. Currency displays correctly (₦ symbol or NGN)
2. Processing fee = ₦115
3. Total = ₦1115
4. All breakdowns show NGN amounts

---

### Test 4: Cap Verification (R5000 ZAR)
**Expected Results:**
- Consultation Fee: R5000
- Paystack Fee: R50 (5000 * 0.015 + 1 = 76 → CAPPED at R50)
- **Total Charged: R5050**
- Practitioner receives: R4000 (80%)
- Platform receives: R1000 (20%)

**What to verify:**
1. Paystack fee is capped at R50 (not R76)
2. Total = R5050 (not R5076)

---

## Browser Console Testing

### 1. Check Fee Calculation
Open browser console and look for:
```
💰 Payment breakdown: {
    consultationFee: 3455,
    paystackFee: 50,
    totalCharged: 3505,
    practitioner: "2764 (80% of consultation)",
    platform: "691 (20% of consultation)",
    currency: "ZAR"
}
```

### 2. Verify Paystack Charge
Check Paystack initialization:
```javascript
amount: 350500,  // Should be totalAmountToPay * 100 = 3505 * 100
```

---

## Database Verification

### After Booking, Run This Query:
```sql
SELECT 
    booking_id,
    practitioner_name,
    consultation_fee,
    paystack_fee,
    total_amount,
    currency,
    ROUND(consultation_fee * 0.8) as calculated_practitioner,
    ROUND(consultation_fee * 0.2) as calculated_platform,
    (total_amount - consultation_fee) as verified_paystack_fee
FROM appointments 
WHERE booking_id = 'APT_XXX'  -- Replace with your booking ID
ORDER BY created_at DESC 
LIMIT 1;
```

**Expected Output for R3455 booking:**
```
booking_id          | APT_1234567890
practitioner_name   | Dr. Johnson
consultation_fee    | 3455
paystack_fee        | 50
total_amount        | 3505
currency            | ZAR
calculated_pract    | 2764
calculated_platform | 691
verified_paystack   | 50
```

---

## Manual Testing Checklist

### Step-by-Step Test Flow

#### 1. Practitioner Selection
- [ ] Select practitioner with R3455 fee
- [ ] Modal shows: "Total: 3505 ZAR (incl. processing fees)"
- [ ] Breakdown shows: "Consultation: 3455 ZAR (2764 to practitioner + 691 platform)"
- [ ] Processing fee shown: "Processing: 50 ZAR"
- [ ] UX message: "ℹ️ The total amount includes secure payment processing and platform service fees."

#### 2. Fill Appointment Details
- [ ] Enter patient name
- [ ] Enter valid email
- [ ] Select date (future date)
- [ ] Select time slot
- [ ] Enter reason for visit

#### 3. Payment Confirmation Dialog
- [ ] Click "Confirm Booking"
- [ ] Dialog shows "TOTAL AMOUNT: 3505 ZAR"
- [ ] Breakdown section shows:
  - [ ] "• Consultation Fee: 3455 ZAR"
  - [ ] "• Processing Fee: 50 ZAR"
  - [ ] "- Practitioner receives: 2764 ZAR (80%)"
  - [ ] "- Platform fee: 691 ZAR (20%)"
- [ ] Cancellation policy shows: "Full refund (3505 ZAR)"
- [ ] UX message visible

#### 4. Paystack Payment
- [ ] Click OK on confirmation
- [ ] Paystack popup opens
- [ ] Amount shows 3505 ZAR (or 350500 kobo)
- [ ] Complete test payment

#### 5. Success Message
- [ ] Success dialog shows "Total Paid: 3505 ZAR"
- [ ] Payment breakdown shows:
  - [ ] "• Consultation Fee: 3455 ZAR"
  - [ ] "- Practitioner receives: 2764 ZAR (80%)"
  - [ ] "- Platform fee: 691 ZAR (20%)"
  - [ ] "• Processing Fee: 50 ZAR"
- [ ] UX message visible
- [ ] Refund message: "automatic refund of 3505 ZAR"

#### 6. My Appointments Dashboard
- [ ] Navigate to My Appointments
- [ ] Find the booking
- [ ] Amount column shows: "3505 ZAR"
- [ ] Sub-line shows: "Fee: 3455 + Processing: 50"
- [ ] Split shows: "Split: 2764 + 691"

#### 7. Cancellation Flow
- [ ] Click Cancel on appointment
- [ ] Dialog shows: "Full refund (3505 ZAR)"
- [ ] Breakdown shows:
  - [ ] "• Consultation: 3455 ZAR"
  - [ ] "• Processing: 50 ZAR"
- [ ] Confirm cancellation
- [ ] Success message: "A refund of 3505 ZAR will be processed"

#### 8. Database Check
- [ ] Run verification query
- [ ] Verify consultation_fee = 3455
- [ ] Verify paystack_fee = 50
- [ ] Verify total_amount = 3505

---

## Edge Cases to Test

### Edge Case 1: Very Low Fee (R50)
- Consultation: R50
- Expected Paystack: R2 (50 * 0.015 + 1 = 1.75 → 2)
- Expected Total: R52

### Edge Case 2: Zero Fee (Free Consultation)
- Consultation: R0
- Expected Paystack: R1 (fixed fee only)
- Expected Total: R1

### Edge Case 3: High Fee Hitting Cap (R10000)
- Consultation: R10000
- Expected Paystack: R50 (10000 * 0.015 + 1 = 151 → CAPPED at R50)
- Expected Total: R10050

### Edge Case 4: Different Currency (USD $200)
- Consultation: $200
- Expected Paystack: $7.90 (200 * 0.039 + 0.10 = 7.80 + 0.10 = 7.90)
- Expected Total: $207.90

---

## Regression Testing

### Ensure These Still Work:
- [ ] AI scheduling suggestions still appear
- [ ] Time slot selection works
- [ ] Email validation enforced
- [ ] Date validation (future dates only)
- [ ] Practitioner info extraction from database
- [ ] Fallback to card parsing if DB fails
- [ ] Default to R500 if both methods fail
- [ ] localStorage fallback if Supabase unavailable
- [ ] Payment cancellation deletes pending appointment
- [ ] Reschedule functionality
- [ ] Status transitions (PENDING → CONFIRMED → COMPLETED)

---

## Performance Testing

### Check Console for Warnings:
- [ ] No errors in fee calculation
- [ ] No undefined values
- [ ] No NaN in calculations
- [ ] Correct currency detected
- [ ] Proper rounding applied

### Verify Logging:
Look for these console messages:
```
✅ Using practitioner fee from database: 3455 ZAR
💰 Payment breakdown: {...}
✅ Payment successful: {...}
```

---

## Multi-Currency Testing Matrix

| Currency | Fee | Expected Paystack | Expected Total | Notes |
|----------|-----|-------------------|----------------|-------|
| ZAR | 500 | 9 | 509 | 1.5% + R1 |
| ZAR | 3455 | 50 | 3505 | Capped at R50 |
| ZAR | 5000 | 50 | 5050 | Verify cap |
| NGN | 1000 | 115 | 1115 | 1.5% + ₦100 |
| NGN | 100000 | 1600 | 101600 | Check cap at ₦2000 |
| KES | 1000 | 20 | 1020 | 1.5% + KSh5 |
| GHS | 500 | 10 | 510 | 1.95% only |
| USD | 250 | 9.85 | 259.85 | 3.9% + $0.10 |
| EUR | 200 | 7.90 | 207.90 | 3.9% + €0.10 |

---

## Known Issues to Watch For

### Issue 1: Rounding Errors
- **Problem**: Fees calculated as decimal (e.g., 8.5)
- **Solution**: Math.round() applied
- **Test**: Verify R500 shows R9 (not R8.50 or R9.00)

### Issue 2: Currency Symbol Display
- **Problem**: Some currencies don't display symbols
- **Solution**: Use currency codes (ZAR, NGN, etc.)
- **Test**: Check all currencies display correctly

### Issue 3: Cap Not Applied
- **Problem**: High fees not capped (e.g., R5000 shows R76 fee)
- **Solution**: Math.min() used for ZAR/NGN
- **Test**: R5000 should show R50 (not R76)

---

## Success Criteria

✅ **All tests pass if:**
1. Total amount = Consultation + Paystack Fee (always)
2. Practitioner gets exactly 80% of consultation (never affected by processing fee)
3. Platform gets exactly 20% of consultation
4. All displays show total amount consistently
5. Refunds include total amount (consultation + processing)
6. Database stores all three values correctly
7. UX message appears in all payment contexts
8. Console logging shows correct calculations
9. No errors in browser console
10. Payment completes successfully in Paystack

---

## Troubleshooting

### If Total is Wrong:
1. Check browser console for fee calculation log
2. Verify paystackFee calculation
3. Check currency detection
4. Verify totalAmountToPay = consultationFee + paystackFee

### If Split is Wrong:
1. Verify split calculated from consultationFee only
2. Check Math.round() applied
3. Ensure paystackFee not included in split

### If Database Values Wrong:
1. Check appointmentData includes all three fields
2. Verify SQL columns exist (paystack_fee, total_amount)
3. Run migration script if needed

---

## Quick Fix Commands

### If columns missing in database:
```sql
ALTER TABLE appointments 
ADD COLUMN IF NOT EXISTS paystack_fee NUMERIC(10, 2),
ADD COLUMN IF NOT EXISTS total_amount NUMERIC(10, 2);
```

### If need to recalculate existing records:
```sql
UPDATE appointments 
SET 
    paystack_fee = LEAST(ROUND(consultation_fee * 0.015) + 1, 50),
    total_amount = consultation_fee + LEAST(ROUND(consultation_fee * 0.015) + 1, 50)
WHERE paystack_fee IS NULL OR total_amount IS NULL;
```

---

*Testing Guide Version 1.0 - Last Updated: 2026-01-28*
