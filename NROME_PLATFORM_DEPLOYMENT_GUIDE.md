# 🚀 NROME MEDICATION DELIVERY PLATFORM - DEPLOYMENT GUIDE

## 📋 OVERVIEW

This guide covers the complete deployment of the Nrome medication delivery platform - a regulatory-ready, South African compliant medication logistics orchestration layer.

**Platform Type:** Licensed logistics + orchestration (NOT a pharmacy)  
**Regulatory Compliance:** SAPC, POPIA, South African Health Act  
**Database:** Supabase PostgreSQL  
**Payment Gateway:** Paystack (South Africa)

---

## 🗂️ DATABASE DEPLOYMENT

### Step 1: Deploy Main Schema

1. **Access Supabase SQL Editor:**
   - Navigate to your Supabase project dashboard
   - Go to SQL Editor

2. **Execute Schema:**
   ```sql
   -- Run the entire nrome_medication_platform_schema.sql file
   ```

3. **Verify Tables Created:**
   ```sql
   SELECT table_name 
   FROM information_schema.tables 
   WHERE table_schema = 'public' 
   ORDER BY table_name;
   ```

   You should see 35+ tables including:
   - `user_profiles`
   - `pharmacies`, `clinics`, `hospitals`
   - `prescriptions`, `prescription_items`
   - `orders`, `order_items`, `order_status_history`
   - `deliveries`, `delivery_tracking`, `delivery_proof`
   - `payments`, `payment_splits`
   - `chronic_enrollments`
   - `messages`, `message_threads`
   - `audit_logs`, `consent_records`

4. **Verify RLS Enabled:**
   ```sql
   SELECT tablename, rowsecurity 
   FROM pg_tables 
   WHERE schemaname = 'public' 
   AND rowsecurity = true;
   ```

---

## 🔐 AUTHENTICATION SETUP

### Step 2: Configure Supabase Auth

1. **Enable Email/Password Auth:**
   - Go to Authentication → Settings
   - Enable Email provider
   - Set up email templates (verification, password reset)

2. **Configure Phone Auth (Optional but Recommended):**
   - Enable Phone provider
   - Configure Twilio for SMS OTP
   - South African phone format: +27XXXXXXXXX

3. **JWT Settings:**
   - JWT expiry: 3600 (1 hour)
   - Ensure `auth.uid()` works in RLS policies

---

## 📦 STORAGE BUCKETS

### Step 3: Create Storage Buckets

Create the following buckets in Supabase Storage:

#### 1. **prescriptions** (Private)
```sql
-- RLS Policy: Patients can upload, pharmacists can view
INSERT INTO storage.buckets (id, name, public)
VALUES ('prescriptions', 'prescriptions', false);

-- Allow patients to upload their prescriptions
CREATE POLICY "Patients can upload prescriptions"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'prescriptions' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Allow patients to view their own prescriptions
CREATE POLICY "Patients can view own prescriptions"
ON storage.objects FOR SELECT
USING (
  bucket_id = 'prescriptions' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Allow pharmacists to view prescriptions for their orders
CREATE POLICY "Pharmacists can view prescriptions"
ON storage.objects FOR SELECT
USING (
  bucket_id = 'prescriptions' AND
  EXISTS (
    SELECT 1 FROM orders o
    JOIN prescriptions p ON o.prescription_id = p.id
    JOIN user_role_assignments ura ON ura.user_id = auth.uid()
    WHERE ura.role = 'pharmacist'
    AND o.pharmacy_id = ura.organization_id
    AND p.prescription_document_url LIKE '%' || name || '%'
  )
);
```

#### 2. **delivery-proof** (Private)
```sql
INSERT INTO storage.buckets (id, name, public)
VALUES ('delivery-proof', 'delivery-proof', false);

-- Drivers can upload proof
CREATE POLICY "Drivers can upload delivery proof"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'delivery-proof' AND
  EXISTS (
    SELECT 1 FROM drivers WHERE user_id = auth.uid()
  )
);

-- Patients and admins can view proof
CREATE POLICY "View delivery proof"
ON storage.objects FOR SELECT
USING (
  bucket_id = 'delivery-proof' AND
  (
    -- Patient can view their delivery proof
    EXISTS (
      SELECT 1 FROM deliveries d
      JOIN orders o ON d.order_id = o.id
      WHERE o.patient_id = auth.uid()
      AND name LIKE '%' || d.id::text || '%'
    )
    OR
    -- Admin can view all
    EXISTS (
      SELECT 1 FROM user_role_assignments
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  )
);
```

#### 3. **pharmacy-documents** (Private - Admin only)
```sql
INSERT INTO storage.buckets (id, name, public)
VALUES ('pharmacy-documents', 'pharmacy-documents', false);

-- Pharmacy managers can upload verification docs
CREATE POLICY "Pharmacy managers upload docs"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'pharmacy-documents' AND
  EXISTS (
    SELECT 1 FROM user_role_assignments
    WHERE user_id = auth.uid() AND role = 'pharmacy_manager'
  )
);

-- Admins can view all pharmacy documents
CREATE POLICY "Admins view pharmacy docs"
ON storage.objects FOR SELECT
USING (
  bucket_id = 'pharmacy-documents' AND
  EXISTS (
    SELECT 1 FROM user_role_assignments
    WHERE user_id = auth.uid() AND role = 'admin'
  )
);
```

---

## 💳 PAYSTACK INTEGRATION

### Step 4: Configure Paystack

1. **Create Paystack Account:**
   - Sign up at https://paystack.com
   - Get Test and Live API keys

2. **Create Environment Variables:**
   ```javascript
   // In Supabase Edge Functions or your backend
   PAYSTACK_SECRET_KEY=sk_test_xxxxxxxxxxxxx
   PAYSTACK_PUBLIC_KEY=pk_test_xxxxxxxxxxxxx
   ```

3. **Create Subaccounts for Pharmacies:**
   ```javascript
   // When pharmacy is verified, create subaccount
   const createPharmacySubaccount = async (pharmacy) => {
     const response = await fetch('https://api.paystack.co/subaccount', {
       method: 'POST',
       headers: {
         Authorization: `Bearer ${PAYSTACK_SECRET_KEY}`,
         'Content-Type': 'application/json'
       },
       body: JSON.stringify({
         business_name: pharmacy.name,
         settlement_bank: pharmacy.bank_name,
         account_number: pharmacy.bank_account_number,
         percentage_charge: 2.5  // Platform fee
       })
     });
     
     const data = await response.json();
     
     // Save subaccount code
     await supabase
       .from('pharmacies')
       .update({ paystack_subaccount_code: data.data.subaccount_code })
       .eq('id', pharmacy.id);
   };
   ```

4. **Payment Split Logic:**
   ```javascript
   // When patient pays, split between pharmacy and platform
   const initiatePayment = async (order) => {
     const response = await fetch('https://api.paystack.co/transaction/initialize', {
       method: 'POST',
       headers: {
         Authorization: `Bearer ${PAYSTACK_SECRET_KEY}`,
         'Content-Type': 'application/json'
       },
       body: JSON.stringify({
         email: patient.email,
         amount: order.total_amount * 100,  // Amount in kobo
         reference: order.order_number,
         subaccount: pharmacy.paystack_subaccount_code,
         transaction_charge: deliveryFee * 100,  // Platform keeps delivery fee
         bearer: 'account'  // Pharmacy bears Paystack fee
       })
     });
     
     const data = await response.json();
     
     // Save payment record
     await supabase.from('payments').insert({
       payment_reference: order.order_number,
       order_id: order.id,
       patient_id: order.patient_id,
       paystack_reference: data.data.reference,
       paystack_access_code: data.data.access_code,
       paystack_authorization_url: data.data.authorization_url,
       amount: order.total_amount,
       status: 'pending'
     });
     
     return data.data.authorization_url;
   };
   ```

5. **Webhook Handler (Supabase Edge Function):**
   ```typescript
   // File: supabase/functions/paystack-webhook/index.ts
   import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
   import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
   
   serve(async (req) => {
     const signature = req.headers.get('x-paystack-signature')
     const body = await req.text()
     
     // Verify webhook signature
     const hash = await crypto.subtle.digest(
       'SHA-512',
       new TextEncoder().encode(body + PAYSTACK_SECRET_KEY)
     )
     
     // ... verification logic
     
     const event = JSON.parse(body)
     
     if (event.event === 'charge.success') {
       const supabase = createClient(
         Deno.env.get('SUPABASE_URL')!,
         Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
       )
       
       // Update payment status
       await supabase
         .from('payments')
         .update({
           status: 'successful',
           paid_at: new Date().toISOString(),
           paystack_response: event.data
         })
         .eq('paystack_reference', event.data.reference)
       
       // Update order payment status
       const { data: payment } = await supabase
         .from('payments')
         .select('order_id')
         .eq('paystack_reference', event.data.reference)
         .single()
       
       await supabase
         .from('orders')
         .update({ payment_status: 'successful', paid_at: new Date().toISOString() })
         .eq('id', payment.order_id)
     }
     
     return new Response('OK', { status: 200 })
   })
   ```

---

## 🤖 EDGE FUNCTIONS

### Step 5: Deploy Edge Functions

#### 1. **Chronic Order Automation**
```typescript
// File: supabase/functions/chronic-order-automation/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )
  
  // Find enrollments due for delivery
  const { data: dueEnrollments } = await supabase
    .from('chronic_enrollments')
    .select('*')
    .eq('status', 'active')
    .lte('next_delivery_date', new Date().toISOString().split('T')[0])
  
  for (const enrollment of dueEnrollments || []) {
    try {
      // Call database function to create order
      await supabase.rpc('create_chronic_order', { enrollment_id: enrollment.id })
      
      console.log(`Created chronic order for enrollment ${enrollment.id}`)
    } catch (error) {
      console.error(`Failed to create order for ${enrollment.id}:`, error)
    }
  }
  
  return new Response(
    JSON.stringify({ processed: dueEnrollments?.length || 0 }),
    { headers: { 'Content-Type': 'application/json' } }
  )
})
```

**Deploy:**
```bash
supabase functions deploy chronic-order-automation
```

**Set up Cron (using Supabase pg_cron extension):**
```sql
-- Run daily at 6 AM
SELECT cron.schedule(
  'daily-chronic-orders',
  '0 6 * * *',
  $$
  SELECT net.http_post(
    url := 'https://your-project.supabase.co/functions/v1/chronic-order-automation',
    headers := '{"Authorization": "Bearer YOUR_ANON_KEY"}'::jsonb
  );
  $$
);
```

#### 2. **Driver Matching (Find Nearest Available Driver)**
```typescript
// File: supabase/functions/assign-driver/index.ts
serve(async (req) => {
  const { orderId } = await req.json()
  
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )
  
  // Get order details
  const { data: order } = await supabase
    .from('orders')
    .select('*, deliveries(*)')
    .eq('id', orderId)
    .single()
  
  // Find available drivers
  const { data: drivers } = await supabase
    .from('drivers')
    .select('*, user_profiles(*)')
    .eq('is_available', true)
    .eq('is_active', true)
  
  // Calculate distances and find nearest
  let nearestDriver = null
  let minDistance = Infinity
  
  for (const driver of drivers || []) {
    const distance = calculateDistance(
      order.deliveries.pickup_latitude,
      order.deliveries.pickup_longitude,
      driver.current_latitude,
      driver.current_longitude
    )
    
    if (distance < minDistance) {
      minDistance = distance
      nearestDriver = driver
    }
  }
  
  if (nearestDriver) {
    // Assign driver
    await supabase
      .from('deliveries')
      .update({
        driver_id: nearestDriver.id,
        assigned_at: new Date().toISOString()
      })
      .eq('order_id', orderId)
    
    // Update order status
    await supabase
      .from('orders')
      .update({ status: 'driver_assigned' })
      .eq('id', orderId)
    
    return new Response(
      JSON.stringify({ success: true, driver: nearestDriver }),
      { headers: { 'Content-Type': 'application/json' } }
    )
  }
  
  return new Response(
    JSON.stringify({ success: false, error: 'No available drivers' }),
    { status: 404, headers: { 'Content-Type': 'application/json' } }
  )
})
```

---

## 📧 NOTIFICATIONS

### Step 6: Set Up Email & SMS

#### Email (SendGrid/Resend)
```typescript
// Order status updates
const sendOrderStatusEmail = async (order, newStatus) => {
  const templates = {
    rx_verified: 'Your prescription has been verified',
    prepared: 'Your medication is ready for delivery',
    picked_up: 'Your order is on the way',
    delivered: 'Your order has been delivered'
  }
  
  await fetch('https://api.sendgrid.com/v3/mail/send', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${SENDGRID_API_KEY}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      personalizations: [{
        to: [{ email: patient.email }],
        dynamic_template_data: {
          order_number: order.order_number,
          status: templates[newStatus]
        }
      }],
      from: { email: 'orders@nrome.co.za' },
      template_id: 'd-xxxxxxxxxxxxxx'
    })
  })
}
```

#### SMS (Twilio)
```typescript
const sendOrderStatusSMS = async (phone, message) => {
  await fetch(`https://api.twilio.com/2010-04-01/Accounts/${TWILIO_ACCOUNT_SID}/Messages.json`, {
    method: 'POST',
    headers: {
      Authorization: `Basic ${btoa(`${TWILIO_ACCOUNT_SID}:${TWILIO_AUTH_TOKEN}`)}`,
      'Content-Type': 'application/x-www-form-urlencoded'
    },
    body: new URLSearchParams({
      To: phone,
      From: '+27XXXXXXXXX',  // Your Twilio number
      Body: message
    })
  })
}
```

---

## 🔔 REALTIME SUBSCRIPTIONS

### Step 7: Configure Realtime

Enable realtime for key tables:

```sql
-- Enable realtime for order tracking
ALTER PUBLICATION supabase_realtime ADD TABLE orders;
ALTER PUBLICATION supabase_realtime ADD TABLE deliveries;
ALTER PUBLICATION supabase_realtime ADD TABLE delivery_tracking;
ALTER PUBLICATION supabase_realtime ADD TABLE messages;
```

**Client-side subscription (Patient tracking order):**
```javascript
const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY)

const subscription = supabase
  .channel('order-tracking')
  .on(
    'postgres_changes',
    {
      event: 'UPDATE',
      schema: 'public',
      table: 'orders',
      filter: `id=eq.${orderId}`
    },
    (payload) => {
      console.log('Order updated:', payload.new)
      updateOrderUI(payload.new)
    }
  )
  .on(
    'postgres_changes',
    {
      event: 'INSERT',
      schema: 'public',
      table: 'delivery_tracking',
      filter: `delivery_id=eq.${deliveryId}`
    },
    (payload) => {
      console.log('Driver location:', payload.new)
      updateDriverMarker(payload.new.latitude, payload.new.longitude)
    }
  )
  .subscribe()
```

---

## 🧪 TESTING CHECKLIST

### Step 8: Test All Flows

#### ✅ Patient Flow
- [ ] Register account
- [ ] Upload prescription
- [ ] Select pharmacy
- [ ] Add OTC items
- [ ] Complete payment via Paystack
- [ ] Track order status
- [ ] Receive delivery
- [ ] Confirm with OTP/signature

#### ✅ Pharmacist Flow
- [ ] Login to pharmacy portal
- [ ] View new prescriptions
- [ ] Verify prescription (accept/reject)
- [ ] Mark medication as prepared
- [ ] Hand over to driver

#### ✅ Driver Flow
- [ ] Login to driver app
- [ ] View assigned delivery
- [ ] Navigate to pharmacy
- [ ] Confirm pickup
- [ ] Navigate to patient
- [ ] Capture delivery proof
- [ ] Complete delivery

#### ✅ Chronic Medication Flow
- [ ] Pharmacist enrolls patient
- [ ] System auto-creates monthly order
- [ ] Patient receives notification
- [ ] Auto-payment or manual
- [ ] Regular delivery

#### ✅ State Machine
- [ ] Cannot skip order statuses
- [ ] Cannot roll back statuses
- [ ] All transitions logged
- [ ] Timestamps auto-updated

#### ✅ RLS Policies
- [ ] Patients can only see own data
- [ ] Drivers cannot see medication details
- [ ] Pharmacists can only access their orders
- [ ] Admins have full access
- [ ] Caregivers can view patient orders

#### ✅ Compliance
- [ ] POPIA consent captured
- [ ] All data access logged
- [ ] Prescription verification mandatory
- [ ] Audit trail immutable
- [ ] Sensitive data encrypted

---

## 🚀 GO LIVE

### Step 9: Production Deployment

1. **Switch Paystack to Live Keys:**
   ```javascript
   PAYSTACK_SECRET_KEY=sk_live_xxxxxxxxxxxxx
   PAYSTACK_PUBLIC_KEY=pk_live_xxxxxxxxxxxxx
   ```

2. **Enable Database Backups:**
   - Supabase automatic daily backups
   - Point-in-time recovery (PITR)

3. **Set Up Monitoring:**
   - Supabase Dashboard metrics
   - Sentry for error tracking
   - Custom alerts for:
     - Failed prescription verifications
     - Payment failures
     - Delivery delays

4. **SSL & Security:**
   - HTTPS enforced
   - Supabase handles SSL
   - Review RLS policies

5. **Legal Compliance:**
   - Update Terms & Conditions
   - Privacy Policy (POPIA compliant)
   - Disclaimer (not medical advice)

---

## 📊 ADMIN CONSOLE QUERIES

### Useful Admin Queries

```sql
-- Daily order summary
SELECT 
  DATE(created_at) AS date,
  COUNT(*) AS total_orders,
  SUM(CASE WHEN status = 'delivered' THEN 1 ELSE 0 END) AS delivered,
  SUM(total_amount) AS revenue
FROM orders
WHERE created_at >= NOW() - INTERVAL '30 days'
GROUP BY DATE(created_at)
ORDER BY date DESC;

-- Pending prescription verifications
SELECT 
  p.id,
  p.prescription_number,
  up.full_name AS patient_name,
  p.created_at,
  EXTRACT(HOUR FROM NOW() - p.created_at) AS hours_pending
FROM prescriptions p
JOIN user_profiles up ON p.patient_id = up.id
WHERE p.status = 'pending_verification'
ORDER BY p.created_at ASC;

-- Driver performance
SELECT 
  d.id,
  up.full_name AS driver_name,
  d.total_deliveries,
  d.successful_deliveries,
  ROUND((d.successful_deliveries::DECIMAL / NULLIF(d.total_deliveries, 0) * 100), 2) AS success_rate,
  d.average_rating
FROM drivers d
JOIN user_profiles up ON d.user_id = up.id
WHERE d.is_active = TRUE
ORDER BY d.average_rating DESC;

-- Pharmacy revenue
SELECT 
  ph.name,
  COUNT(o.id) AS total_orders,
  SUM(o.subtotal) AS revenue,
  AVG(o.subtotal) AS avg_order_value
FROM pharmacies ph
JOIN orders o ON ph.id = o.pharmacy_id
WHERE o.payment_status = 'successful'
AND o.created_at >= NOW() - INTERVAL '30 days'
GROUP BY ph.id, ph.name
ORDER BY revenue DESC;
```

---

## 🔧 MAINTENANCE

### Regular Tasks

**Daily:**
- Monitor prescription verification queue
- Check failed payments
- Review flagged messages (auto-moderation)

**Weekly:**
- Review driver performance
- Check pharmacy license expiries
- Audit chronic medication deliveries

**Monthly:**
- Export compliance reports
- Review audit logs
- Update medication catalog

---

## 📞 SUPPORT

### Emergency Contacts
- **Database Issues:** Supabase Support
- **Payment Issues:** Paystack Support
- **SAPC Compliance:** [SAPC Contact]
- **POPIA Queries:** [Information Regulator]

---

## ✅ DEPLOYMENT COMPLETE

Your Nrome medication delivery platform is now ready to orchestrate safe, compliant medication logistics across South Africa! 🇿🇦💊🚀
