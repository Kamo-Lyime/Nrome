# PAYSTACK FEE QUICK REFERENCE

## 🎯 THE GOLDEN RULE

```
Patient pays = Consultation Fee + Paystack Fee

Practitioner gets = 80% of Consultation Fee (ONLY)
Platform gets     = 20% of Consultation Fee (ONLY)
Paystack gets     = Processing Fee (ONLY)
```

---

## 💰 FEE FORMULAS BY CURRENCY

| Currency | Formula | Cap | Example (Input → Output) |
|----------|---------|-----|--------------------------|
| **ZAR** | 1.5% + R1 | R50 | R3455 → R50 |
| **NGN** | 1.5% + ₦100 | ₦2000 | ₦50000 → ₦850 |
| **KES** | 1.5% + KSh5 | None | KSh5000 → KSh80 |
| **GHS** | 1.95% | None | GH₵1000 → GH₵20 |
| **USD** | 3.9% + $0.10 | None | $250 → $9.85 |

---

## 📊 QUICK CALCULATION EXAMPLES

### Example: R3455 Consultation (ZAR)

```
1. Consultation Fee:     R3455
   ├─ Practitioner (80%): R2764
   └─ Platform (20%):     R691

2. Paystack Fee:         R50
   (3455 × 0.015) + 1 = 52.825 → 53 → CAPPED → R50

3. TOTAL PATIENT PAYS:   R3505
```

### Example: ₦50,000 Consultation (NGN)

```
1. Consultation Fee:     ₦50,000
   ├─ Practitioner (80%): ₦40,000
   └─ Platform (20%):     ₦10,000

2. Paystack Fee:         ₦850
   (50000 × 0.015) + 100 = 750 + 100 = 850

3. TOTAL PATIENT PAYS:   ₦50,850
```

---

## 🔧 CODE SNIPPETS

### Calculate Paystack Fee
```javascript
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
    paystackFee = Math.round(consultationFee * 0.039 * 100) / 100;
    if (currency === 'USD' || currency === 'EUR') paystackFee += 0.10;
}
```

### Calculate Split & Total
```javascript
const totalAmountToPay = consultationFee + paystackFee;
const practitionerAmount = Math.round(consultationFee * 0.8);
const platformAmount = Math.round(consultationFee * 0.2);
```

### Charge via Paystack
```javascript
const amountInKobo = totalAmountToPay * 100;
paystackHandler.initiatePayment({ amount: amountInKobo, ... });
```

---

## 💬 UX MESSAGE (USE EVERYWHERE)

```
ℹ️ The total amount includes secure payment processing and platform service fees.
```

---

## 📱 DISPLAY TEMPLATES

### Practitioner Selection
```
💳 Total: [TOTAL] [CURR] (incl. processing fees)

• Consultation: [FEE] [CURR] ([PRACT] to practitioner + [PLAT] platform)
• Processing: [PAYSTACK] [CURR]
ℹ️ The total amount includes secure payment processing and platform service fees.
```

### Payment Dialog
```
💳 PAYMENT REQUIRED

TOTAL AMOUNT: [TOTAL] [CURR]

Breakdown:
• Consultation Fee: [FEE] [CURR]
• Processing Fee: [PAYSTACK] [CURR]
  - Practitioner receives: [PRACT] [CURR] (80%)
  - Platform fee: [PLAT] [CURR] (20%)

ℹ️ The total amount includes secure payment processing and platform service fees.
```

### Success Message
```
✅ PAYMENT SUCCESSFUL!

Total Paid: [TOTAL] [CURR]

Payment Breakdown:
• Consultation Fee: [FEE] [CURR]
  - Practitioner receives: [PRACT] [CURR] (80%)
  - Platform fee: [PLAT] [CURR] (20%)
• Processing Fee: [PAYSTACK] [CURR]

ℹ️ The total amount includes secure payment processing and platform service fees.
```

### Cancellation Refund
```
✅ Full refund ([TOTAL] [CURR]) - cancelled ≥24h before
   • Consultation: [FEE] [CURR]
   • Processing: [PAYSTACK] [CURR]
```

---

## 🗄️ DATABASE FIELDS

```sql
consultation_fee    NUMERIC(10,2)  -- e.g., 3455.00
paystack_fee        NUMERIC(10,2)  -- e.g., 50.00
total_amount        NUMERIC(10,2)  -- e.g., 3505.00
currency            TEXT           -- e.g., 'ZAR'
```

---

## 🧪 TESTING QUICK CHECKS

### ZAR Tests
| Consultation | Expected Paystack | Expected Total |
|--------------|-------------------|----------------|
| R500 | R9 | R509 |
| R1000 | R16 | R1016 |
| R3455 | R50 | R3505 |
| R5000 | R50 | R5050 |

### NGN Tests
| Consultation | Expected Paystack | Expected Total |
|--------------|-------------------|----------------|
| ₦1000 | ₦115 | ₦1115 |
| ₦50000 | ₦850 | ₦50850 |
| ₦200000 | ₦2000 | ₦202000 |

### USD Tests
| Consultation | Expected Paystack | Expected Total |
|--------------|-------------------|----------------|
| $100 | $4.00 | $104.00 |
| $250 | $9.85 | $259.85 |
| $1000 | $39.10 | $1039.10 |

---

## ✅ VERIFICATION SQL

```sql
-- Check recent booking
SELECT 
    booking_id,
    consultation_fee,
    paystack_fee,
    total_amount,
    currency,
    ROUND(consultation_fee * 0.8) as pract_should_be,
    ROUND(consultation_fee * 0.2) as plat_should_be
FROM appointments 
WHERE booking_id = 'APT_XXX';

-- Expected output for R3455:
-- consultation_fee: 3455
-- paystack_fee: 50
-- total_amount: 3505
-- pract_should_be: 2764
-- plat_should_be: 691
```

---

## 🚨 COMMON ISSUES

| Problem | Check | Fix |
|---------|-------|-----|
| Total wrong | Browser console | Verify paystackFee calculation |
| Split affected | Practitioner amount | Use consultationFee only, not total |
| Cap not applied | High fees | Check Math.min() for ZAR/NGN |
| DB columns missing | SQL error | Run add_paystack_fee_columns.sql |
| Refund wrong | Refund amount | Use totalAmount * 100, not fee * 100 |

---

## 📞 SUPPORT RESPONSE TEMPLATE

**Q: "Why is the total higher than the consultation fee?"**

**A:**
```
The total includes both your consultation and secure payment processing:

• Consultation: [FEE] [CURR]
  - Your practitioner receives [PRACT] [CURR] (80%)
  - Platform service fee: [PLAT] [CURR] (20%)
• Processing: [PAYSTACK] [CURR]

TOTAL: [TOTAL] [CURR]

All fees are disclosed before payment. If you cancel ≥24h before 
your appointment, you'll receive a full refund of [TOTAL] [CURR].
```

---

## 🎓 KEY FACTS

1. ✅ **80/20 split NEVER changes** - always based on consultation fee only
2. ✅ **Processing fees added on top** - patient absorbs this cost
3. ✅ **Full transparency** - all fees shown before payment
4. ✅ **Complete refunds** - patient gets back everything paid (total amount)
5. ✅ **Multi-currency** - automatic calculation for each currency
6. ✅ **Capped fees** - ZAR max R50, NGN max ₦2000

---

## 📁 FILES MODIFIED/CREATED

### Modified
- **nurse.html** (9 sections updated)

### Created
- **add_paystack_fee_columns.sql** (DB migration)
- **PAYSTACK_FEE_IMPLEMENTATION.md** (700+ lines)
- **PAYSTACK_FEE_TESTING.md** (testing guide)
- **PAYSTACK_FEE_UPDATE_SUMMARY.md** (overview)
- **PAYMENT_FLOW_DIAGRAM.md** (visual flows)
- **PAYSTACK_FEE_QUICK_REFERENCE.md** (this file)

---

## 🚀 DEPLOYMENT STEPS

1. **Database:** Run `add_paystack_fee_columns.sql` in Supabase
2. **Deploy:** Upload updated `nurse.html` to Vercel
3. **Test:** Book appointment, verify amounts
4. **Verify:** Check database record
5. **Monitor:** Watch first real transactions

---

*Quick Reference v1.0 - Print/bookmark this page for easy access*
