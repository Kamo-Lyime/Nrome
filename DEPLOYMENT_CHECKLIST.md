# DEPLOYMENT CHECKLIST

## ✅ Complete Implementation Checklist

---

## 📋 PRE-DEPLOYMENT VERIFICATION

### Documentation Created ✅
- [x] PAYSTACK_FEE_INDEX.md (Master index)
- [x] PAYSTACK_FEE_QUICK_REFERENCE.md (Quick lookup)
- [x] PAYSTACK_FEE_UPDATE_SUMMARY.md (Change overview)
- [x] PAYSTACK_FEE_IMPLEMENTATION.md (Technical docs)
- [x] PAYSTACK_FEE_TESTING.md (Testing guide)
- [x] PAYMENT_FLOW_DIAGRAM.md (Visual flows)
- [x] add_paystack_fee_columns.sql (Database migration)

### Code Updated ✅
- [x] nurse.html - Section 1: Fee calculation function (lines ~1790-1830)
- [x] nurse.html - Section 2: Appointment data storage (lines ~1838-1845)
- [x] nurse.html - Section 3: Payment confirmation dialog (lines ~1848-1865)
- [x] nurse.html - Section 4: Paystack initialization (lines ~1894-1896)
- [x] nurse.html - Section 5: Success message (lines ~1930-1947)
- [x] nurse.html - Section 6: Refund messages (lines ~1963-1965)
- [x] nurse.html - Section 7: Practitioner selection (lines ~1220-1260)
- [x] nurse.html - Section 8: My Appointments (lines ~3995-4005)
- [x] nurse.html - Section 9: Cancellation dialog (lines ~2198-2242)

---

## 🗄️ STEP 1: DATABASE MIGRATION

### Execute SQL Script

1. **Open Supabase Dashboard**
   - Go to your Supabase project
   - Navigate to SQL Editor

2. **Run Migration Script**
   ```sql
   -- Copy contents from add_paystack_fee_columns.sql
   
   ALTER TABLE appointments 
   ADD COLUMN IF NOT EXISTS paystack_fee NUMERIC(10, 2);
   
   ALTER TABLE appointments 
   ADD COLUMN IF NOT EXISTS total_amount NUMERIC(10, 2);
   
   -- Update existing records
   UPDATE appointments 
   SET 
       paystack_fee = LEAST(ROUND(COALESCE(consultation_fee, 500) * 0.015) + 1, 50),
       total_amount = COALESCE(consultation_fee, 500) + 
                      LEAST(ROUND(COALESCE(consultation_fee, 500) * 0.015) + 1, 50)
   WHERE paystack_fee IS NULL OR total_amount IS NULL;
   ```

3. **Verify Columns Created**
   ```sql
   SELECT column_name, data_type 
   FROM information_schema.columns 
   WHERE table_name = 'appointments' 
   AND column_name IN ('paystack_fee', 'total_amount');
   ```
   
   **Expected Output:**
   ```
   column_name    | data_type
   ---------------|-----------
   paystack_fee   | numeric
   total_amount   | numeric
   ```

4. **Verify Existing Records Updated**
   ```sql
   SELECT 
       booking_id,
       consultation_fee,
       paystack_fee,
       total_amount,
       currency
   FROM appointments 
   ORDER BY created_at DESC 
   LIMIT 5;
   ```
   
   **Check:** All records should have `paystack_fee` and `total_amount` values

### ✅ Checkpoint
- [ ] SQL script executed successfully
- [ ] Columns created (`paystack_fee`, `total_amount`)
- [ ] Existing records updated with calculated values
- [ ] No errors in SQL execution

---

## 🚀 STEP 2: CODE DEPLOYMENT

### Deploy to Vercel

1. **Verify Current File**
   - Open `nurse.html` in your editor
   - Search for: `totalAmountToPay`
   - Confirm you see the new fee calculation code

2. **Deploy to Vercel**
   
   **Option A: Git Deploy (Recommended)**
   ```powershell
   cd C:\Users\Kamono\Desktop\Nromebasic
   git add nurse.html
   git commit -m "Add Paystack processing fees on top of consultation fee"
   git push origin main
   ```
   
   **Option B: Manual Upload**
   - Go to Vercel dashboard
   - Select your project
   - Upload `nurse.html` manually
   - Wait for deployment to complete

3. **Verify Deployment**
   - Open your live site: https://[your-domain].vercel.app/nurse.html
   - Open browser DevTools (F12)
   - Search page source for: `totalAmountToPay`
   - Confirm new code is live

### ✅ Checkpoint
- [ ] nurse.html deployed to Vercel
- [ ] Deployment successful (no errors)
- [ ] New code visible in page source
- [ ] Site loads without JavaScript errors

---

## 🧪 STEP 3: FUNCTIONALITY TESTING

### Test 1: R500 Consultation (Basic Test)

1. **Open nurse.html on live site**
2. **Click "AI Appointment Booking"**
3. **Select practitioner with R500 fee**
4. **Expected in modal:**
   ```
   💳 Total: 509 ZAR (incl. processing fees)
   • Consultation: 500 ZAR (400 to practitioner + 100 platform)
   • Processing: 9 ZAR
   ℹ️ The total amount includes secure payment processing...
   ```

5. **Fill appointment details:**
   - Patient Name: Test Patient
   - Email: test@example.com
   - Date: Tomorrow
   - Time: 10:00 AM
   - Reason: Test booking

6. **Click "Confirm Booking"**

7. **Expected payment dialog:**
   ```
   💳 PAYMENT REQUIRED
   
   TOTAL AMOUNT: 509 ZAR
   
   Breakdown:
   • Consultation Fee: 500 ZAR
   • Processing Fee: 9 ZAR
     - Practitioner receives: 400 ZAR (80%)
     - Platform fee: 100 ZAR (20%)
   
   ℹ️ The total amount includes secure payment processing...
   ```

8. **Click OK**

9. **Expected Paystack popup:**
   - Amount: 50900 kobo (509 * 100)
   - Can proceed with test payment

10. **Complete test payment** (use test card)

11. **Expected success message:**
    ```
    ✅ PAYMENT SUCCESSFUL!
    
    Total Paid: 509 ZAR
    
    Payment Breakdown:
    • Consultation Fee: 500 ZAR
      - Practitioner receives: 400 ZAR (80%)
      - Platform fee: 100 ZAR (20%)
    • Processing Fee: 9 ZAR
    ```

### ✅ Test 1 Checkpoint
- [ ] Modal shows total 509 ZAR
- [ ] Payment dialog shows breakdown correctly
- [ ] Paystack charges 50900 kobo
- [ ] Success message shows all fees
- [ ] UX message appears in all places

---

### Test 2: Database Verification

1. **Open Supabase Dashboard**

2. **Run Query:**
   ```sql
   SELECT 
       booking_id,
       practitioner_name,
       consultation_fee,
       paystack_fee,
       total_amount,
       currency,
       ROUND(consultation_fee * 0.8) as practitioner_should_get,
       ROUND(consultation_fee * 0.2) as platform_should_get
   FROM appointments 
   WHERE patient_email = 'test@example.com'
   ORDER BY created_at DESC 
   LIMIT 1;
   ```

3. **Expected Output:**
   ```
   booking_id:         APT_...
   practitioner_name:  [Practitioner Name]
   consultation_fee:   500.00
   paystack_fee:       9.00
   total_amount:       509.00
   currency:           ZAR
   practitioner_...:   400
   platform_should_get: 100
   ```

### ✅ Test 2 Checkpoint
- [ ] Database record created
- [ ] consultation_fee = 500
- [ ] paystack_fee = 9
- [ ] total_amount = 509
- [ ] All three fields populated

---

### Test 3: R3455 Consultation (User's Example)

1. **Register test practitioner** (or modify existing)
   - Consultation Fee: 3455 ZAR

2. **Book appointment with this practitioner**

3. **Expected modal:**
   ```
   💳 Total: 3505 ZAR (incl. processing fees)
   • Consultation: 3455 ZAR (2764 to practitioner + 691 platform)
   • Processing: 50 ZAR
   ```

4. **Expected payment dialog:**
   ```
   TOTAL AMOUNT: 3505 ZAR
   
   Breakdown:
   • Consultation Fee: 3455 ZAR
   • Processing Fee: 50 ZAR
     - Practitioner receives: 2764 ZAR (80%)
     - Platform fee: 691 ZAR (20%)
   ```

5. **Expected Paystack amount:** 350500 kobo

6. **Verify database:**
   ```sql
   consultation_fee: 3455.00
   paystack_fee:     50.00
   total_amount:     3505.00
   ```

### ✅ Test 3 Checkpoint
- [ ] Fee cap applied (R50, not R53)
- [ ] Total = 3505 (not 3508)
- [ ] Split correct (2764 + 691 = 3455)
- [ ] Database accurate

---

### Test 4: My Appointments Display

1. **Navigate to My Appointments** (on nurse.html page)

2. **Find your test appointment**

3. **Expected display:**
   ```
   Amount: 509 ZAR
   Fee: 500 + Processing: 9
   Split: 400 + 100
   ```
   
   OR for R3455:
   ```
   Amount: 3505 ZAR
   Fee: 3455 + Processing: 50
   Split: 2764 + 691
   ```

### ✅ Test 4 Checkpoint
- [ ] Total amount displayed correctly
- [ ] Breakdown shows fee + processing
- [ ] Split shows 80/20 correctly

---

### Test 5: Cancellation & Refund

1. **Cancel the test appointment**

2. **Expected cancellation dialog:**
   ```
   Cancel Appointment?
   
   Refund Policy:
   ✅ Full refund (509 ZAR) - cancelled ≥24h before
      • Consultation: 500 ZAR
      • Processing: 9 ZAR
   ```
   
   OR for R3455:
   ```
   ✅ Full refund (3505 ZAR) - cancelled ≥24h before
      • Consultation: 3455 ZAR
      • Processing: 50 ZAR
   ```

3. **Confirm cancellation**

4. **Expected success message:**
   ```
   ✅ Appointment Cancelled
   
   A refund of 509 ZAR will be processed within 5-7 business days.
     • Consultation: 500 ZAR
     • Processing: 9 ZAR
   ```

5. **Verify in Paystack Dashboard:**
   - Check refund was initiated
   - Amount: 50900 kobo (for R500 test)
   - Amount: 350500 kobo (for R3455 test)

### ✅ Test 5 Checkpoint
- [ ] Refund dialog shows total amount
- [ ] Breakdown includes consultation + processing
- [ ] Paystack refund API called with correct amount
- [ ] Database updated (status = CANCELLED)

---

## 🌍 STEP 4: MULTI-CURRENCY TESTING (Optional)

### Test Different Currencies

#### NGN (Nigeria)
- [ ] Test ₦1000: Expected total ₦1115 (fee ₦115)
- [ ] Test ₦50000: Expected total ₦50850 (fee ₦850)

#### KES (Kenya)
- [ ] Test KSh1000: Expected total KSh1020 (fee KSh20)

#### USD (International)
- [ ] Test $250: Expected total $259.85 (fee $9.85)

---

## 🖥️ STEP 5: BROWSER CONSOLE VERIFICATION

### Check Console Logs

1. **Open browser DevTools** (F12)
2. **Go to Console tab**
3. **Book appointment**
4. **Look for logs:**

   ```javascript
   ✅ Using practitioner fee from database: 3455 ZAR
   
   💰 Payment breakdown: {
     consultationFee: 3455,
     paystackFee: 50,
     totalCharged: 3505,
     practitioner: "2764 (80% of consultation)",
     platform: "691 (20% of consultation)",
     currency: "ZAR"
   }
   
   ✅ Payment successful: {...}
   ```

### ✅ Console Checkpoint
- [ ] Fee extraction log shows correct amount
- [ ] Payment breakdown shows all values
- [ ] No errors in console
- [ ] No warnings related to payment

---

## 📊 STEP 6: PRODUCTION MONITORING

### First 24 Hours

1. **Monitor Transactions**
   - [ ] Check Paystack dashboard every 2 hours
   - [ ] Verify amounts charged match database records
   - [ ] Confirm no failed payments

2. **Monitor Database**
   ```sql
   SELECT 
       COUNT(*) as total_bookings,
       SUM(total_amount) as total_charged,
       SUM(consultation_fee) as consultations,
       SUM(paystack_fee) as processing_fees,
       currency
   FROM appointments 
   WHERE created_at > NOW() - INTERVAL '24 hours'
   AND status NOT IN ('CANCELLED', 'DELETED')
   GROUP BY currency;
   ```

3. **Watch for Issues**
   - [ ] Total amounts incorrect
   - [ ] Paystack fees not calculated
   - [ ] Refunds failing
   - [ ] User complaints

---

## 👥 STEP 7: SUPPORT TEAM TRAINING

### Distribute Documentation
- [ ] Share PAYSTACK_FEE_QUICK_REFERENCE.md with support team
- [ ] Print support response templates
- [ ] Conduct 15-minute training session
- [ ] Answer any questions

### Key Points to Cover
1. Total = Consultation + Processing
2. 80/20 split NEVER affected by processing
3. Full refunds include everything
4. Use response templates provided

---

## ✅ FINAL VERIFICATION CHECKLIST

### Database ✅
- [ ] Columns created (paystack_fee, total_amount)
- [ ] Existing records updated
- [ ] New bookings populate all fields
- [ ] No NULL values in new bookings

### Code Deployment ✅
- [ ] nurse.html deployed successfully
- [ ] No JavaScript errors
- [ ] All 9 sections updated
- [ ] Page loads correctly

### Functionality ✅
- [ ] R500 test passed
- [ ] R3455 test passed
- [ ] Fee caps working (ZAR: R50)
- [ ] My Appointments displays correctly
- [ ] Cancellation refunds correct amount
- [ ] UX message appears everywhere

### User Experience ✅
- [ ] Modal shows total upfront
- [ ] Payment dialog clear and detailed
- [ ] Success message comprehensive
- [ ] Dashboard shows breakdown
- [ ] Cancellation transparent

### Documentation ✅
- [ ] Quick reference created
- [ ] Implementation guide complete
- [ ] Testing guide available
- [ ] Support templates ready
- [ ] Flow diagrams available

---

## 🎯 SUCCESS CRITERIA

The deployment is successful if:

1. **Fee Calculation**
   - ✅ R500 → Total R509 (Paystack R9)
   - ✅ R3455 → Total R3505 (Paystack R50, capped)
   - ✅ Split always 80/20 of consultation only

2. **Database**
   - ✅ All three fields populated in new records
   - ✅ Values accurate and match calculations
   - ✅ Existing records updated correctly

3. **User Experience**
   - ✅ Total amount displayed consistently
   - ✅ Breakdown visible at all stages
   - ✅ UX message present
   - ✅ No user confusion

4. **Payments & Refunds**
   - ✅ Paystack charges correct total
   - ✅ Refunds process full amount
   - ✅ No failed transactions
   - ✅ Status updates correctly

---

## 🚨 ROLLBACK PLAN (If Issues Occur)

### If Critical Issues Found:

1. **Immediate Action**
   ```powershell
   # Revert nurse.html to previous version
   git revert HEAD
   git push origin main
   ```

2. **Database Rollback** (if needed)
   ```sql
   -- Remove columns (data will be lost)
   ALTER TABLE appointments 
   DROP COLUMN IF EXISTS paystack_fee,
   DROP COLUMN IF EXISTS total_amount;
   ```

3. **Notify Users**
   - Post notice: "Payment system temporarily under maintenance"
   - Provide ETA for fix
   - Offer alternative booking method

---

## 📈 POST-DEPLOYMENT MONITORING

### Week 1 Metrics to Track

```sql
-- Daily summary
SELECT 
    DATE(created_at) as booking_date,
    COUNT(*) as bookings,
    AVG(consultation_fee) as avg_consultation,
    AVG(paystack_fee) as avg_processing,
    AVG(total_amount) as avg_total,
    currency
FROM appointments 
WHERE created_at > NOW() - INTERVAL '7 days'
GROUP BY DATE(created_at), currency
ORDER BY booking_date DESC;
```

### Red Flags to Watch:
- ❌ total_amount NULL in new records
- ❌ paystack_fee = 0 when it should be calculated
- ❌ Failed Paystack transactions
- ❌ User complaints about amounts
- ❌ Refund failures

---

## 🎓 REFERENCE MATERIALS

### Quick Access Links
- [Quick Reference](PAYSTACK_FEE_QUICK_REFERENCE.md) - Formulas & templates
- [Testing Guide](PAYSTACK_FEE_TESTING.md) - Test scenarios
- [Implementation](PAYSTACK_FEE_IMPLEMENTATION.md) - Technical details
- [Flow Diagram](PAYMENT_FLOW_DIAGRAM.md) - Visual representation
- [Index](PAYSTACK_FEE_INDEX.md) - Master document

---

## ✅ DEPLOYMENT COMPLETE

Once all checkpoints are verified:

- [ ] Database migration successful
- [ ] Code deployed to production
- [ ] All tests passed
- [ ] No errors detected
- [ ] Support team trained
- [ ] Monitoring active

**Status:** 🟢 READY FOR PRODUCTION

**Deployed By:** ________________

**Date:** ________________

**Verified By:** ________________

---

*Use this checklist as your deployment roadmap. Check off each item as you complete it.*
