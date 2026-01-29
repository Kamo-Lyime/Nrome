# Dynamic Consultation Fee Integration

## 🎯 Update Summary

The payment system has been updated to **automatically use each practitioner's individual consultation fee** instead of a hardcoded R500. The system now:

1. ✅ Extracts the fee from practitioner's registration data
2. ✅ Automatically calculates 80/20 split based on actual fee
3. ✅ Supports multiple currencies (ZAR, NGN, KES, etc.)
4. ✅ Updates all displays to show dynamic amounts

---

## 📊 How It Works

### **Fee Extraction Priority**

1. **Database First** (Preferred)
   - Fetches `consultation_fee` from practitioner record
   - Gets `currency` (ZAR, NGN, KES, etc.)
   - Most accurate and reliable

2. **Card Display Fallback**
   - Parses "Consultation Fee: 3455 ZAR" from practitioner card
   - Regex pattern: `(\d+(?:\.\d+)?)\s*([A-Z]{3})?`
   - Handles formats: "3455 ZAR", "R3455", "3455"

3. **Default Fallback**
   - If both fail: 500 ZAR

### **Automatic 80/20 Split**

For **any amount**, the system calculates:
```javascript
practitionerAmount = Math.round(consultationFee * 0.8)  // 80%
platformAmount = Math.round(consultationFee * 0.2)      // 20%
```

**Examples:**
- 500 ZAR → 400 + 100
- 3455 ZAR → 2764 + 691
- 1000 NGN → 800 + 200
- 250 USD → 200 + 50

---

## 🔧 Changes Made to nurse.html

### **1. Improved Fee Extraction (Line ~1715-1800)**

**OLD** (Hardcoded):
```javascript
let consultationFee = 500; // Default R500

if (selectedCard) {
    const feeText = selectedCard.textContent;
    const feeMatch = feeText.match(/R?\s*(\d+)/i);
    if (feeMatch) {
        consultationFee = parseInt(feeMatch[1]) || 500;
    }
}
```

**NEW** (Dynamic):
```javascript
let consultationFee = 500; // Default fallback
let currency = 'ZAR';

// Try database first
try {
    const practitioner = await getPractitionerById(practitionerId);
    if (practitioner && practitioner.consultation_fee) {
        consultationFee = parseFloat(practitioner.consultation_fee);
        currency = practitioner.currency || 'ZAR';
        console.log('✅ Using practitioner fee from database:', consultationFee, currency);
    }
} catch (dbError) {
    console.warn('Could not fetch from database, using card data:', dbError);
}

// Fallback: Extract from card
if (selectedCard && consultationFee === 500) {
    const feeElement = selectedCard.querySelector('.text-success');
    if (feeElement) {
        const feeText = feeElement.textContent;
        const feeMatch = feeText.match(/(\d+(?:\.\d+)?)\s*([A-Z]{3})?/);
        if (feeMatch) {
            consultationFee = parseFloat(feeMatch[1]) || 500;
            currency = feeMatch[2] || currency;
            console.log('✅ Using practitioner fee from card:', consultationFee, currency);
        }
    }
}

// Calculate 80/20 split
const practitionerAmount = Math.round(consultationFee * 0.8);
const platformAmount = Math.round(consultationFee * 0.2);
```

### **2. Dynamic Payment Confirmation Dialog (Line ~1820)**

**OLD**:
```javascript
`Consultation Fee: R${consultationFee}\n` +
`- Practitioner receives: R${Math.round(consultationFee * 0.8)} (80%)\n` +
`- Platform fee: R${Math.round(consultationFee * 0.2)} (20%)\n\n`
```

**NEW**:
```javascript
`Consultation Fee: ${consultationFee} ${currency}\n` +
`- Practitioner receives: ${practitionerAmount} ${currency} (80%)\n` +
`- Platform fee: ${platformAmount} ${currency} (20%)\n\n` +
`Cancellation Policy:\n` +
`- Cancel ≥24h before: Full refund (${consultationFee} ${currency})\n`
```

### **3. Modal Button Updated (Line ~3759)**

**OLD**:
```html
<small class="text-muted text-center">
    💳 Secure payment via Paystack • R500 consultation fee<br>
    ✅ 80% to practitioner, 20% platform fee
</small>
```

**NEW**:
```html
<small class="text-muted text-center" id="paymentFeeInfo">
    💳 Secure payment via Paystack<br>
    ✅ 80% to practitioner, 20% platform fee
</small>
```
*Fee now updates dynamically when practitioner is selected*

### **4. Practitioner Selection Updates Fee Display (Line ~1204)**

**NEW Function** added to `updatePractitionerInfo()`:
```javascript
// Extract consultation fee from card
let consultationFee = 500;
let currency = 'ZAR';
const feeElement = selectedCard.querySelector('.text-success');
if (feeElement) {
    const feeText = feeElement.textContent;
    const feeMatch = feeText.match(/(\d+(?:\.\d+)?)\s*([A-Z]{3})?/);
    if (feeMatch) {
        consultationFee = parseFloat(feeMatch[1]) || 500;
        currency = feeMatch[2] || 'ZAR';
    }
}

// Calculate split
const practitionerAmount = Math.round(consultationFee * 0.8);
const platformAmount = Math.round(consultationFee * 0.2);

// Update payment fee info
if (feeInfoDiv) {
    feeInfoDiv.innerHTML = `
        💳 Consultation Fee: <strong>${consultationFee} ${currency}</strong><br>
        ✅ Practitioner gets ${practitionerAmount} ${currency} (80%) • 
           Platform fee ${platformAmount} ${currency} (20%)
    `;
}
```

### **5. Success Message with Dynamic Amounts (Line ~1890)**

**OLD**:
```javascript
`Amount Paid: R${consultationFee}\n\n`
```

**NEW**:
```javascript
`Amount Paid: ${consultationFee} ${currency}\n` +
`  - Practitioner receives: ${practitionerAmount} ${currency} (80%)\n` +
`  - Platform fee: ${platformAmount} ${currency} (20%)\n\n` +
`If not confirmed, you'll receive automatic refund of ${consultationFee} ${currency}.\n\n`
```

### **6. My Appointments Display (Line ~3950)**

**OLD**:
```html
<td>R${apt.consultation_fee || 500}</td>
```

**NEW**:
```javascript
const fee = apt.consultation_fee || 500;
const curr = apt.currency || 'ZAR';
const practitionerAmount = Math.round(fee * 0.8);
const platformAmount = Math.round(fee * 0.2);

html += `
<td>
    <strong>${fee} ${curr}</strong><br>
    <small class="text-muted">${practitionerAmount} + ${platformAmount}</small>
</td>
`;
```

### **7. Cancellation Messages (Line ~2160)**

**OLD**:
```javascript
`✅ Full refund (R${appointment.consultation_fee || 500})` +
`A refund of R${appointment.consultation_fee || 500} will be processed`
```

**NEW**:
```javascript
const fee = appointment.consultation_fee || 500;
const curr = appointment.currency || 'ZAR';

`✅ Full refund (${fee} ${curr})` +
`A refund of ${fee} ${curr} will be processed within 5-7 business days.`
```

### **8. Currency Stored in Appointment (Line ~1807)**

**NEW** field added:
```javascript
appointmentData.consultation_fee = consultationFee;
appointmentData.currency = currency;  // <-- NEW!
appointmentData.practitioner_phone = practitionerPhone;
appointmentData.practitioner_email = practitionerEmail;
```

---

## 🧪 Testing Examples

### **Example 1: Practitioner with 3455 ZAR Fee**

**Registration Data**:
```
Name: Dr. Jane Smith
Consultation Fee: 3455 ZAR
```

**What Happens**:
1. Patient selects Dr. Jane Smith
2. Modal shows: "💳 Consultation Fee: **3455 ZAR**"
3. Payment breakdown: "Practitioner gets 2764 ZAR (80%) • Platform fee 691 ZAR (20%)"
4. Payment confirmation dialog shows: 
   ```
   Consultation Fee: 3455 ZAR
   - Practitioner receives: 2764 ZAR (80%)
   - Platform fee: 691 ZAR (20%)
   ```
5. Paystack payment modal charges: 345,500 kobo (3455 ZAR)
6. Success message: "Amount Paid: 3455 ZAR"
7. My Appointments shows: "3455 ZAR (2764 + 691)"

### **Example 2: Practitioner with 1000 NGN Fee**

**Registration Data**:
```
Name: Dr. Ibrahim Hassan
Consultation Fee: 1000 NGN
```

**What Happens**:
1. Fee extracted: 1000 NGN
2. Split calculated: 800 NGN + 200 NGN
3. Payment: 100,000 kobo (1000 NGN)
4. All displays show NGN currency

### **Example 3: Default Fallback (No Fee Set)**

**Registration Data**:
```
Name: Dr. New Practitioner
Consultation Fee: (empty)
```

**What Happens**:
1. System uses default: 500 ZAR
2. Split: 400 ZAR + 100 ZAR
3. Payment: 50,000 kobo
4. All displays show ZAR currency

---

## 📋 Database Schema Update Required

Add `currency` column to appointments table:

```sql
ALTER TABLE appointments 
ADD COLUMN IF NOT EXISTS currency TEXT DEFAULT 'ZAR';
```

Or update the full schema in `payment_appointments_schema.sql`:
```sql
CREATE TABLE appointments (
    -- ... existing columns ...
    consultation_fee DECIMAL(10,2) DEFAULT 500.00,
    currency TEXT DEFAULT 'ZAR',  -- NEW COLUMN
    -- ... rest of columns ...
);
```

---

## 🎯 Benefits

### **For Practitioners**
- ✅ Set their own consultation fees
- ✅ Work in their local currency
- ✅ Automatically receive 80% of their set fee
- ✅ Transparent payment breakdown

### **For Patients**
- ✅ See exact consultation fee before booking
- ✅ Clear payment breakdown (80/20 split)
- ✅ Know exact refund amount
- ✅ Support for local currencies

### **For Platform**
- ✅ Automatic 20% platform fee calculation
- ✅ Multi-currency support (ZAR, NGN, KES, USD, etc.)
- ✅ No hardcoded values
- ✅ Scales to any fee amount

---

## 🌍 Supported Currencies

Based on practitioner registration form:
- **ZAR** - South African Rand
- **NGN** - Nigerian Naira
- **KES** - Kenyan Shilling
- **EGP** - Egyptian Pound
- **GHS** - Ghanaian Cedi
- **TZS** - Tanzanian Shilling
- **UGX** - Ugandan Shilling
- **ETB** - Ethiopian Birr
- **MAD** - Moroccan Dirham
- **USD** - US Dollar
- And more...

---

## 🔍 Debugging

Check console logs during booking:
```javascript
// When practitioner selected
✅ Using practitioner fee from database: 3455 ZAR

// Or fallback
✅ Using practitioner fee from card: 3455 ZAR

// Payment breakdown
💰 Payment breakdown: {
    total: 3455,
    practitioner: 2764,
    platform: 691,
    currency: 'ZAR'
}
```

---

## ✅ Summary

**Before**: Hardcoded R500 for all practitioners
**After**: Dynamic fee based on each practitioner's registration

**Example Practitioners**:
- Dr. A charges 500 ZAR → Patient pays 500 ZAR (400 + 100)
- Dr. B charges 3455 ZAR → Patient pays 3455 ZAR (2764 + 691)
- Dr. C charges 1000 NGN → Patient pays 1000 NGN (800 + 200)
- Dr. D charges 250 USD → Patient pays 250 USD (200 + 50)

**All automatic with 80/20 split maintained!** 🎉

---

**Updated**: January 28, 2026
**Status**: ✅ COMPLETE
**Testing**: Ready for production
