# 🚀 IMPLEMENTATION CHECKLIST
## Payment-Enabled Appointment Booking System

Use this checklist to deploy the complete system to production.

---

## Phase 1: Database Setup ✅

### 1.1 Run SQL Schema
- [ ] Open Supabase Dashboard → SQL Editor
- [ ] Copy contents of `payment_appointments_schema.sql`
- [ ] Execute the SQL (creates all tables, triggers, views)
- [ ] Verify tables created:
  ```sql
  SELECT table_name FROM information_schema.tables 
  WHERE table_schema = 'public' 
  AND table_name IN (
    'appointments', 
    'payment_transactions', 
    'practitioner_subaccounts', 
    'appointment_logs'
  );
  ```
- [ ] Should return 4 rows

### 1.2 Verify RLS Policies
- [ ] Check Row Level Security is enabled:
  ```sql
  SELECT tablename, rowsecurity 
  FROM pg_tables 
  WHERE schemaname = 'public';
  ```
- [ ] All tables should have `rowsecurity = true`

### 1.3 Test Views
- [ ] Run: `SELECT * FROM pending_confirmations;`
- [ ] Run: `SELECT * FROM overdue_confirmations;`
- [ ] Run: `SELECT * FROM upcoming_appointments;`
- [ ] Should return empty results (no data yet)

---

## Phase 2: Paystack Configuration ✅

### 2.1 Test Mode Setup
- [ ] Verify test keys in `js/paystack-integration.js`:
  - Public: `pk_test_74336bdb2862bdcde9f71f4c2e3243fc3a2fedf6`
  - Secret: `sk_test_ce04e3466d797c150e1b7c81ce8d3a5c51bbc098`

### 2.2 Paystack Dashboard
- [ ] Login to https://dashboard.paystack.com
- [ ] Navigate to Settings → API Keys & Webhooks
- [ ] Confirm test keys match
- [ ] Note down webhook secret (for later)

### 2.3 Test Payment
- [ ] Use Paystack test card: `4084084084084081`
- [ ] CVV: `408`
- [ ] Expiry: Any future date
- [ ] PIN: `0000`

---

## Phase 3: File Deployment ✅

### 3.1 Upload JavaScript Modules
- [ ] Upload `js/paystack-integration.js`
- [ ] Upload `js/appointment-booking.js`
- [ ] Verify files accessible in browser

### 3.2 Upload API Endpoints
- [ ] Create `api/webhooks/` folder
- [ ] Upload `api/webhooks/paystack.js`
- [ ] Create `api/cron/` folder
- [ ] Upload `api/cron/appointment-automation.js`

### 3.3 Upload HTML Pages
- [ ] Upload `appointment-booking.html`
- [ ] Test page loads: `https://yourdomain.com/appointment-booking.html`

### 3.4 Update Configuration
- [ ] Update `vercel.json` with cron jobs and webhooks
- [ ] Commit and push to GitHub/deploy to Vercel

---

## Phase 4: Environment Variables ✅

### 4.1 Vercel Environment Variables
Go to Vercel Dashboard → Your Project → Settings → Environment Variables

Add the following:

| Name | Value | Environment |
|------|-------|-------------|
| `SUPABASE_URL` | `https://vpmuooztcqzrrfsvjzwl.supabase.co` | Production, Preview, Development |
| `SUPABASE_SERVICE_ROLE_KEY` | Your service role key from Supabase | Production |
| `PAYSTACK_SECRET_KEY` | `sk_test_...` (test) or `sk_live_...` (production) | Production |
| `NODE_ENV` | `production` | Production |

- [ ] All environment variables added
- [ ] Redeploy after adding variables

### 4.2 Verify Environment Variables
- [ ] Create test endpoint to check:
  ```javascript
  // api/test-env.js
  export default function handler(req, res) {
      res.json({
          supabase: !!process.env.SUPABASE_URL,
          paystack: !!process.env.PAYSTACK_SECRET_KEY,
          service_role: !!process.env.SUPABASE_SERVICE_ROLE_KEY
      });
  }
  ```
- [ ] Visit `/api/test-env` → All should be `true`

---

## Phase 5: Webhook Setup ✅

### 5.1 Deploy Webhook Endpoint
- [ ] Verify webhook is live: `https://yourdomain.com/api/webhooks/paystack`
- [ ] Test with curl:
  ```bash
  curl -X POST https://yourdomain.com/api/webhooks/paystack
  ```
- [ ] Should return 405 (Method Not Allowed) - this is expected

### 5.2 Register Webhook in Paystack
- [ ] Login to Paystack Dashboard
- [ ] Go to Settings → Webhooks
- [ ] Add webhook URL: `https://yourdomain.com/api/webhooks/paystack`
- [ ] Copy the webhook secret
- [ ] Add to Vercel env vars as `PAYSTACK_WEBHOOK_SECRET`

### 5.3 Test Webhook
- [ ] In Paystack Dashboard, send test webhook
- [ ] Check Vercel logs for webhook receipt
- [ ] Should see: "Webhook received: charge.success"

---

## Phase 6: Cron Jobs ✅

### 6.1 Verify Cron Configuration
- [ ] Check `vercel.json` has cron entries:
  - `/api/cron/check-confirmations` - hourly
  - `/api/cron/check-no-shows` - hourly
  - `/api/cron/send-reminders` - daily 8 AM

### 6.2 Enable Cron on Vercel
- [ ] Vercel Dashboard → Project → Settings → Cron Jobs
- [ ] Verify cron jobs are listed and enabled
- [ ] Note: Cron jobs only work on Pro plan

### 6.3 Test Cron Jobs Manually
```bash
# Test confirmation check
curl -X POST https://yourdomain.com/api/cron/check-confirmations

# Test no-show check
curl -X POST https://yourdomain.com/api/cron/check-no-shows

# Test reminders
curl -X POST https://yourdomain.com/api/cron/send-reminders
```

- [ ] All should return `{ "success": true }`

---

## Phase 7: Integration with nurse.html ✅

### 7.1 Add Paystack Script
In `nurse.html` `<head>`:
```html
<!-- Paystack Inline -->
<script src="https://js.paystack.co/v1/inline.js"></script>
```

### 7.2 Add Module Scripts
In `nurse.html` before `</body>`:
```html
<!-- Payment System -->
<script src="js/paystack-integration.js"></script>
<script src="js/appointment-booking.js"></script>
```

### 7.3 Add Booking Button
Replace or add to the AI Appointment Booking section:
```html
<button class="btn btn-primary" onclick="window.location.href='appointment-booking.html'">
    Book Appointment with Payment
</button>
```

- [ ] Scripts added to nurse.html
- [ ] Booking button added
- [ ] Button links to appointment-booking.html

---

## Phase 8: Testing End-to-End ✅

### 8.1 Test Practitioner Creation
Create a test practitioner:
```sql
INSERT INTO medical_practitioners (
    name, profession, email_address, phone_number, 
    consultation_fee, currency, verified
) VALUES (
    'Dr. Test Practitioner', 
    'General Practitioner', 
    'test@example.com', 
    '+27123456789', 
    500, 
    'ZAR', 
    true
);
```

- [ ] Practitioner created
- [ ] Appears in practitioner dropdown

### 8.2 Test Complete Booking Flow

**Step 1: Create Appointment**
- [ ] Visit `appointment-booking.html`
- [ ] Select test practitioner
- [ ] Choose date and time
- [ ] Enter patient details
- [ ] Proceed to payment

**Step 2: Payment**
- [ ] Payment summary shows R500.00
- [ ] Click "Pay R500"
- [ ] Paystack modal opens
- [ ] Use test card: `4084084084084081`
- [ ] Complete payment

**Step 3: Verify Database**
```sql
SELECT * FROM appointments 
ORDER BY created_at DESC 
LIMIT 1;
```

- [ ] Appointment exists
- [ ] Status = 'PENDING_CONFIRMATION'
- [ ] payment_status = 'success'
- [ ] payment_reference exists
- [ ] confirmation_deadline is set (24h from now)

**Step 4: Verify Transaction**
```sql
SELECT * FROM payment_transactions 
ORDER BY created_at DESC 
LIMIT 1;
```

- [ ] Transaction recorded
- [ ] transaction_type = 'payment'
- [ ] amount = 500
- [ ] platform_fee = 100
- [ ] practitioner_amount = 400

**Step 5: Verify Logs**
```sql
SELECT * FROM appointment_logs 
WHERE appointment_id = (
    SELECT id FROM appointments 
    ORDER BY created_at DESC LIMIT 1
);
```

- [ ] Multiple log entries
- [ ] 'appointment_created'
- [ ] 'payment_successful'

### 8.3 Test Practitioner Confirmation

Manually confirm the appointment:
```sql
UPDATE appointments 
SET status = 'CONFIRMED', 
    confirmed_at = NOW() 
WHERE booking_id = 'YOUR_BOOKING_ID';
```

- [ ] Appointment confirmed
- [ ] Status = 'CONFIRMED'

### 8.4 Test Refund Flow

**Test Unconfirmed Timeout:**
1. Create another appointment
2. Wait for webhook to update to PENDING_CONFIRMATION
3. Set confirmation_deadline to past:
   ```sql
   UPDATE appointments 
   SET confirmation_deadline = NOW() - INTERVAL '1 hour' 
   WHERE booking_id = 'YOUR_BOOKING_ID';
   ```
4. Run cron manually:
   ```bash
   curl -X POST https://yourdomain.com/api/cron/check-confirmations
   ```

- [ ] Appointment status changed to 'REFUNDED'
- [ ] Refund transaction recorded
- [ ] Log entry created

**Test Patient Cancellation:**
- [ ] Book new appointment
- [ ] Confirm it
- [ ] Use cancellation function in UI
- [ ] Verify refund issued (if >24h before)

---

## Phase 9: Production Readiness ✅

### 9.1 Switch to Live Paystack Keys
- [ ] Get live keys from Paystack
- [ ] Update `PAYSTACK_SECRET_KEY` in Vercel
- [ ] Update public key in `js/paystack-integration.js`
- [ ] Redeploy

### 9.2 Test with Real Payment
- [ ] Use real card (small amount)
- [ ] Verify payment appears in Paystack dashboard
- [ ] Verify appointment created
- [ ] Initiate refund to test refund flow

### 9.3 Security Audit
- [ ] RLS policies tested for all tables
- [ ] Webhook signature verification working
- [ ] Service role key only in server-side functions
- [ ] CORS headers configured correctly
- [ ] Environment variables not exposed to client

### 9.4 Legal Compliance
- [ ] Terms & Conditions reviewed by lawyer
- [ ] POPIA compliance verified
- [ ] Cancellation policy clearly displayed
- [ ] Fee transparency implemented
- [ ] Privacy policy published

---

## Phase 10: Monitoring & Maintenance ✅

### 10.1 Set Up Monitoring
- [ ] Vercel Analytics enabled
- [ ] Supabase Dashboard bookmarked
- [ ] Paystack Dashboard bookmarked
- [ ] Error tracking configured (Sentry/Bugsnag)

### 10.2 Create Monitoring Dashboards

**Supabase SQL Editor - Save these queries:**

**Daily Appointment Stats:**
```sql
SELECT 
    DATE(created_at) as date,
    COUNT(*) as total_appointments,
    COUNT(*) FILTER (WHERE status = 'CONFIRMED') as confirmed,
    COUNT(*) FILTER (WHERE status = 'COMPLETED') as completed,
    COUNT(*) FILTER (WHERE status = 'REFUNDED') as refunded,
    COUNT(*) FILTER (WHERE status = 'NO_SHOW') as no_shows
FROM appointments
WHERE created_at >= NOW() - INTERVAL '30 days'
GROUP BY DATE(created_at)
ORDER BY date DESC;
```

**Revenue Summary:**
```sql
SELECT 
    DATE(completed_at) as date,
    SUM(amount) as total_revenue,
    SUM(platform_fee) as platform_revenue,
    SUM(practitioner_amount) as practitioner_revenue,
    COUNT(*) as transaction_count
FROM payment_transactions
WHERE status = 'success' 
  AND transaction_type = 'payment'
  AND completed_at >= NOW() - INTERVAL '30 days'
GROUP BY DATE(completed_at)
ORDER BY date DESC;
```

- [ ] Monitoring queries saved
- [ ] Dashboards bookmarked

### 10.3 Set Up Alerts

**Vercel Notifications:**
- [ ] Deployment notifications enabled
- [ ] Error rate alerts enabled

**Custom Alerts (optional):**
- [ ] High refund rate (>10%)
- [ ] Low confirmation rate (<80%)
- [ ] Payment failures spike
- [ ] Webhook failures

---

## Phase 11: Documentation ✅

### 11.1 User Documentation
- [ ] Patient booking guide created
- [ ] Practitioner onboarding guide created
- [ ] FAQ page published
- [ ] Video tutorials (optional)

### 11.2 Internal Documentation
- [ ] `PAYMENT_BOOKING_GUIDE.md` reviewed
- [ ] `TERMS_AND_CONDITIONS.md` reviewed
- [ ] Database schema documented
- [ ] API endpoints documented

### 11.3 Support Resources
- [ ] Support email configured
- [ ] Support ticket system (optional)
- [ ] Knowledge base (optional)

---

## Phase 12: Launch ✅

### 12.1 Soft Launch
- [ ] Enable for limited practitioners (beta)
- [ ] Monitor first 10 appointments closely
- [ ] Gather feedback
- [ ] Fix any issues

### 12.2 Marketing Materials
- [ ] Announcement email drafted
- [ ] Social media posts prepared
- [ ] Website updated
- [ ] Press release (optional)

### 12.3 Full Launch
- [ ] Enable for all practitioners
- [ ] Send announcement emails
- [ ] Post on social media
- [ ] Monitor system closely for 48 hours

---

## Ongoing Maintenance Checklist 📅

### Daily
- [ ] Check Vercel logs for errors
- [ ] Monitor Paystack dashboard for failed payments
- [ ] Check Supabase for unusual activity

### Weekly
- [ ] Review appointment stats
- [ ] Check refund rate
- [ ] Review no-show rate
- [ ] Check practitioner confirmation rate

### Monthly
- [ ] Review revenue reports
- [ ] Analyze user feedback
- [ ] Update documentation if needed
- [ ] Security review

### Quarterly
- [ ] Full system audit
- [ ] Performance optimization
- [ ] Feature updates planning
- [ ] Terms & Conditions review

---

## Emergency Contacts 🚨

**Paystack Support:**
- Email: support@paystack.com
- Phone: +234 1 888 7688

**Supabase Support:**
- Dashboard: https://supabase.com/dashboard/support
- Discord: https://discord.supabase.com

**Vercel Support:**
- Dashboard: https://vercel.com/help
- Email: support@vercel.com

---

## Quick Reference URLs 🔗

| Service | URL |
|---------|-----|
| Supabase Dashboard | https://supabase.com/dashboard |
| Paystack Dashboard | https://dashboard.paystack.com |
| Vercel Dashboard | https://vercel.com/dashboard |
| Your App | https://yourdomain.com |
| Appointment Booking | https://yourdomain.com/appointment-booking.html |
| Webhook Endpoint | https://yourdomain.com/api/webhooks/paystack |

---

## Success Metrics 📊

Track these KPIs to measure success:

- **Booking Conversion Rate**: Visitors → Completed Bookings
- **Payment Success Rate**: Should be >95%
- **Confirmation Rate**: Practitioners confirming within 24h (target >90%)
- **Refund Rate**: Should be <10%
- **No-Show Rate**: Typical 5-15% (industry standard)
- **Revenue Growth**: Month-over-month increase

---

**Good luck with your launch! 🚀**

Need help? Review `PAYMENT_BOOKING_GUIDE.md` for detailed troubleshooting.
