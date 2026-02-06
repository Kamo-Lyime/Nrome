# Payment System & Pharmacy Payouts Explained

## 🧪 Test Mode vs Production Mode

### Test Mode (Current Setup)
- **Paystack Key**: `pk_test_74336bdb2862bdcde9f71f4c2e3243fc3a2fedf6`
- **Real Money**: ❌ NO real money is transferred
- **Purpose**: Test the payment flow, order workflow, and user experience
- **Test Cards**: Use Paystack test card numbers:
  - **Success**: `4084084084084081` (CVV: 408, Expiry: any future date)
  - **Insufficient Funds**: `5060666666666666666`
  - **Failed**: `506066666666666666`
- **Pharmacy Payout**: ❌ No actual payout happens in test mode

### Production Mode (Live)
- **Paystack Key**: `pk_live_...` (from Paystack dashboard)
- **Real Money**: ✅ YES - actual bank transfers
- **Purpose**: Accept real customer payments
- **Real Cards**: Customers use their actual debit/credit cards
- **Pharmacy Payout**: ✅ Pharmacies receive real money via bank transfer

---

## 💰 How Pharmacy Payouts Work (Production)

### Setup Required:
1. **Pharmacy Bank Details**:
   - Pharmacies upload bank details during registration
   - Stored in `pharmacies` table: `bank_name`, `bank_account_number`

2. **Paystack Subaccounts** (for automatic splits):
   - Create subaccount for each pharmacy in Paystack
   - Link pharmacy bank account to subaccount
   - Automatic payout when order is delivered

### Payout Flow:

#### Option 1: Manual Payouts (Current Implementation)
```
1. Customer pays R222.26 → Paystack
2. Paystack deducts processing fee (R5.26)
3. Remaining R217.00 goes to Nrome account
4. When order is delivered:
   - Nrome keeps R16.70 (10% platform fee)
   - Nrome transfers R200.30 to pharmacy bank account
   - Transfer can be done via:
     * Paystack Transfer API
     * Manual bank transfer
     * Batch weekly/monthly payouts
```

#### Option 2: Automatic Splits (Recommended for Production)
```
1. Customer pays R222.26 → Paystack
2. Paystack automatically splits:
   - R5.26 → Paystack (processing fee)
   - R200.30 → Pharmacy subaccount (auto-deposited to their bank)
   - R16.70 → Nrome account (platform fee)
3. Pharmacy receives money within 2-7 business days
4. No manual intervention needed
```

---

## 🔄 Current Order Flow

### 1. Patient Places Order
- Selects medications
- Enters delivery info
- Clicks "Pay Securely with Paystack"

### 2. Order Created in Database
```javascript
{
  order_number: "NRM-1770335959622",
  patient_id: "...",
  pharmacy_id: "...",
  subtotal: 100.00,
  delivery_fee: 50.00,
  paystack_fee: 4.75,
  platform_fee: 10.00,      // 10% of subtotal
  pharmacy_amount: 140.00,   // subtotal + delivery - platform_fee
  total_amount: 154.75,      // subtotal + delivery + paystack_fee
  payment_status: "pending",
  status: "created"
}
```

### 3. Paystack Payment Modal Opens
- Customer enters card details
- Paystack processes payment
- In test mode: No real charge

### 4. Payment Callback (THIS IS THE FIX)
```javascript
callback: function(response) {
  // Updates order in database:
  supabaseClient
    .from('orders')
    .update({
      payment_status: 'paid',
      payment_reference: response.reference,
      status: 'pending_confirmation'
    })
    .eq('id', order.id)  // ✅ Now uses order.id (reliable)
}
```

### 5. Pharmacy Dashboard
- Sees new order with status "Pending Confirmation"
- Payment badge shows "PAID" ✅
- Can click "Confirm" to accept order

---

## 🐛 Why "PENDING" Was Showing

### The Problem:
1. Order was created with `payment_status: 'pending'`
2. Payment was successful on Paystack
3. **Callback failed to update the database** because:
   - Was using `order_number` instead of `order.id`
   - RLS policies might block the update
   - Silent failure (no error shown to user)

### The Fix:
1. ✅ Use `order.id` instead of `order_number` (more reliable)
2. ✅ Add `updated_at` timestamp
3. ✅ Add detailed console logging
4. ✅ Show error message if update fails
5. ✅ Better success message with reference number

---

## 📊 Database Columns Needed

### Run This SQL First:
```sql
-- From add_order_fee_columns.sql
ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_status VARCHAR(50) DEFAULT 'pending';
ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_reference VARCHAR(100);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS paystack_fee DECIMAL(10,2) DEFAULT 0;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS platform_fee DECIMAL(10,2) DEFAULT 0;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS pharmacy_amount DECIMAL(10,2) DEFAULT 0;
```

### Check if columns exist:
```sql
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'orders' 
  AND column_name IN ('payment_status', 'payment_reference', 'paystack_fee', 'platform_fee', 'pharmacy_amount');
```

---

## 🔐 RLS Policy Check

### Orders table needs policy:
```sql
-- Allow authenticated users to update their own orders (for payment callback)
CREATE POLICY "Users can update own orders"
ON orders FOR UPDATE
USING (auth.uid() = patient_id);
```

---

## 🧪 Testing the Fix

### 1. Check Console Logs:
After clicking "Pay Securely with Paystack", you should see:
```
Order created successfully: {id: "...", order_number: "NRM-...", ...}
Order items inserted. Order ID: ...
Paystack callback triggered! {reference: "...", ...}
Order updated successfully: [...]
```

### 2. After Payment Success:
- Alert shows: "✅ Payment successful! Reference: [ref] Your order is now awaiting pharmacy confirmation."
- Redirects to medication.html
- In "My Orders" tab, order shows:
  - Badge: "PAID" (green) ✅
  - Status: "Awaiting Pharmacy Confirmation"

### 3. Pharmacy Dashboard:
- Order appears in list
- Payment badge: "PAID" ✅
- Status: "Pending Confirmation"
- "Confirm" button available
- Fee breakdown shows pharmacy will receive correct amount

---

## 💳 Production Setup Checklist

### 1. Switch to Live Paystack Keys
```javascript
// In config.js
PAYSTACK_PUBLIC_KEY: 'pk_live_YOUR_LIVE_KEY'  // Get from dashboard
```

### 2. Verify Paystack Account
- Business verification complete
- Bank account linked
- Settlement account set

### 3. Create Pharmacy Subaccounts (Optional but Recommended)
```javascript
// API call to create subaccount for each pharmacy
const response = await fetch('https://api.paystack.co/subaccount', {
  method: 'POST',
  headers: {
    'Authorization': 'Bearer sk_live_YOUR_SECRET_KEY',
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    business_name: pharmacy.name,
    settlement_bank: pharmacy.bank_code,
    account_number: pharmacy.bank_account_number,
    percentage_charge: 90  // Pharmacy gets 90%, Nrome gets 10%
  })
});
```

### 4. Update Payment Integration
```javascript
// Add split_code to payment
const paystackConfig = {
  key: window.CONFIG.PAYSTACK_PUBLIC_KEY,
  email: email,
  amount: Math.round(currentOrder.total * 100),
  currency: 'ZAR',
  ref: orderNumber,
  subaccount: pharmacy.paystack_subaccount_code,  // Auto-split to pharmacy
  transaction_charge: Math.round(platformFee * 100),  // Nrome's 10%
  // ... rest of config
};
```

### 5. Webhook for Payment Confirmation
```javascript
// In api/webhooks/paystack.js
// Verify payment on your server
// Update order status
// Send confirmation emails
```

---

## 📞 Support

If payment shows as successful but order still shows "PENDING":

1. Check browser console for errors
2. Check if SQL columns exist: Run `add_order_fee_columns.sql`
3. Check RLS policies allow order updates
4. Check order in Supabase dashboard directly
5. Look for the payment_reference field - if it's empty, callback didn't run

---

## 🎯 Summary

**Test Mode (Now):**
- No real money
- Use test cards
- Test the workflow
- Fix shows better error messages

**Production Mode (Later):**
- Real payments
- Real payouts to pharmacies
- Use subaccounts for automatic splits
- Webhook for payment verification

The fix ensures the order is properly updated after payment, showing "PAID" status and moving to "Pending Confirmation" for pharmacy to process.
