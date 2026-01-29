# PAYMENT-ENABLED APPOINTMENT BOOKING SYSTEM
## Complete Implementation Guide

## 🚀 Overview

This system implements a fully automated appointment booking workflow with Paystack payment integration, automated refunds, and no-show handling for medical practitioners across Africa.

## 📋 Features

### Core Workflow
1. **Patient Selects Slot** → Creates appointment with `PENDING_PAYMENT` status
2. **Payment via Paystack** → R500 split automatically (80% practitioner, 20% platform)
3. **Payment Success** → Status changes to `PENDING_CONFIRMATION`
4. **Practitioner Confirms** → Status changes to `CONFIRMED`
5. **Appointment Occurs** → Status changes to `COMPLETED`
6. **Automated Refunds** → Various scenarios handled automatically
7. **No-Show Detection** → Automated checking and fee handling

### Payment Split
- **Total**: R500.00
- **Practitioner**: R400.00 (80%)
- **Platform**: R100.00 (20%)

## 🗄️ Database Setup

### Step 1: Run SQL Schema

Execute `payment_appointments_schema.sql` in your Supabase SQL Editor:

```bash
# This creates:
- Enhanced appointments table with payment fields
- practitioner_subaccounts table
- payment_transactions table
- appointment_logs table (audit trail)
- Automated triggers and views
```

### Key Tables Created

#### `appointments`
- Tracks all appointment bookings
- Payment status and references
- Confirmation deadlines
- Refund tracking

#### `payment_transactions`
- Complete audit trail of all payments
- Refunds and splits tracked
- Webhook data stored

#### `practitioner_subaccounts`
- Paystack subaccount codes for each practitioner
- Bank account details
- Settlement tracking

#### `appointment_logs`
- Every status change logged
- Actor tracking (patient/practitioner/system/webhook)
- Complete audit trail

## 💳 Paystack Configuration

### Test Keys (Provided)
```javascript
Public Key: pk_test_74336bdb2862bdcde9f71f4c2e3243fc3a2fedf6
Secret Key: sk_test_ce04e3466d797c150e1b7c81ce8d3a5c51bbc098
```

### Environment Variables

Create a `.env` file:

```env
# Supabase
SUPABASE_URL=https://vpmuooztcqzrrfsvjzwl.supabase.co
SUPABASE_ANON_KEY=your_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key

# Paystack
PAYSTACK_PUBLIC_KEY=pk_test_74336bdb2862bdcde9f71f4c2e3243fc3a2fedf6
PAYSTACK_SECRET_KEY=sk_test_ce04e3466d797c150e1b7c81ce8d3a5c51bbc098

# App
NODE_ENV=development
```

### Webhook Setup

1. **In Paystack Dashboard**:
   - Go to Settings → Webhooks
   - Add webhook URL: `https://yourdomain.com/api/webhooks/paystack`
   - Copy the webhook secret

2. **Events to Listen For**:
   - `charge.success` - Payment completed
   - `refund.processed` - Refund completed
   - `transfer.success` - Payout to practitioner

## 🔧 Installation & Deployment

### 1. Install Dependencies

```bash
npm install @supabase/supabase-js crypto
```

### 2. Deploy Files

Upload these files to your project:

```
/js/
  ├── paystack-integration.js    # Core Paystack integration
  └── appointment-booking.js     # Booking workflow logic

/api/
  ├── webhooks/
  │   └── paystack.js            # Webhook handler
  └── cron/
      └── appointment-automation.js  # Automated tasks

/
  ├── appointment-booking.html   # User interface
  └── payment_appointments_schema.sql  # Database schema
```

### 3. Integrate into nurse.html

Add to the `<head>` section:

```html
<!-- Paystack Inline -->
<script src="https://js.paystack.co/v1/inline.js"></script>

<!-- Our modules -->
<script src="js/paystack-integration.js"></script>
<script src="js/appointment-booking.js"></script>
```

Add appointment booking button:

```html
<button onclick="window.location.href='appointment-booking.html'" class="btn btn-primary">
    Book Appointment with Payment
</button>
```

### 4. Set Up Cron Jobs

Configure Vercel cron jobs in `vercel.json`:

```json
{
  "crons": [
    {
      "path": "/api/cron/check-confirmations",
      "schedule": "0 * * * *"
    },
    {
      "path": "/api/cron/check-no-shows",
      "schedule": "0 * * * *"
    },
    {
      "path": "/api/cron/send-reminders",
      "schedule": "0 8 * * *"
    }
  ]
}
```

## 📱 Usage Flow

### For Patients

1. **Browse practitioners** on nurse.html
2. **Click "Book Appointment"**
3. **Select practitioner, date, time**
4. **Enter patient details**
5. **Review payment summary**
6. **Click "Pay R500"**
7. **Paystack modal opens** → Complete payment
8. **Receive confirmation** → Status: PENDING_CONFIRMATION
9. **Wait for practitioner** to confirm (max 24h)
10. **Attend appointment** → Status: COMPLETED

### For Practitioners

1. **Receive notification** of new appointment
2. **Confirm within 24 hours** or auto-refund triggers
3. **View confirmed appointments**
4. **Mark attendance** after appointment
5. **Receive payout** (80% of R500 = R400)

## 🔄 Automated Workflows

### 1. Unconfirmed Timeout (Runs hourly)

**Scenario**: Practitioner doesn't confirm within 24 hours

**Actions**:
- System detects overdue confirmation deadline
- Initiates 100% refund via Paystack API
- Updates appointment status to `REFUNDED`
- Records refund transaction
- Logs audit trail
- Notifies patient

**Code**: `api/cron/appointment-automation.js` → `checkUnconfirmedAppointments()`

### 2. No-Show Detection (Runs hourly)

**Scenario**: Appointment time has passed

**Actions**:
- System checks all CONFIRMED appointments past their time
- Marks as `NO_SHOW` by default
- Applies no-show fee (full amount)
- Notifies practitioner to override if patient attended
- Logs action

**Code**: `api/cron/appointment-automation.js` → `checkNoShows()`

### 3. Appointment Reminders (Runs daily at 8 AM)

**Actions**:
- Finds all appointments for tomorrow
- Sends email/SMS reminders to patients
- Logs reminder sent

## 💰 Refund Policy Matrix

| Case | Scenario | Refund Amount | Trigger |
|------|----------|---------------|---------|
| **A** | Practitioner timeout (no confirmation) | 100% | Automated after 24h |
| **B** | Practitioner explicitly declines | 100% | Manual by practitioner |
| **C** | Patient cancels ≥24h before | 100% | Manual by patient |
| **D** | Patient cancels <24h before | 0% (no-show policy) | Manual by patient |
| **E** | Practitioner cancels after confirm | 100% + goodwill credit | Manual by practitioner |
| **F** | Patient disputes after appointment | Case-by-case | Manual review |

### Refund Implementation

Each case is handled in `appointment-booking.js`:

```javascript
// Case A: Timeout
booking.handleUnconfirmedTimeout(appointmentId)

// Case B: Decline
booking.handlePractitionerDecline(appointmentId, reason)

// Case C & D: Patient cancel
booking.handlePatientCancellation(appointmentId, reason)

// Case E: Practitioner cancel
booking.handlePractitionerCancellation(appointmentId, reason)
```

## 🔐 Security & Compliance

### POPIA Compliance (South Africa)

✅ **Patient Data Protection**
- All patient data encrypted at rest (Supabase)
- Row Level Security (RLS) policies enforced
- Patients can only see their own appointments

✅ **Consent Logging**
- Every booking action logged in `appointment_logs`
- Payment consent implied by completing payment
- Cancellation policy shown before payment

✅ **Data Access Control**
- Practitioners can only see appointments booked with them
- Service role key used only in server-side functions
- Webhook signature verification prevents tampering

### Payment Security

✅ **PCI Compliance**
- Paystack handles all card data
- Your app never touches card details
- Paystack Inline JS is PCI-DSS certified

✅ **Webhook Verification**
```javascript
// Always verify Paystack signature
const hash = crypto
    .createHmac('sha512', PAYSTACK_SECRET_KEY)
    .update(JSON.stringify(req.body))
    .digest('hex');

if (hash !== req.headers['x-paystack-signature']) {
    return res.status(401).json({ error: 'Invalid signature' });
}
```

## 🧪 Testing Guide

### Test Payment Flow

1. **Use Paystack Test Cards**:
   ```
   Success: 4084084084084081
   Decline: 4084080000000408
   ```

2. **Test Workflow**:
   ```bash
   # Create test practitioner
   INSERT INTO medical_practitioners (name, profession, email_address)
   VALUES ('Dr. Test', 'GP', 'test@example.com');

   # Book appointment → Use test card
   # Check Supabase → appointment should be PENDING_CONFIRMATION
   # Confirm manually or wait 24h for auto-refund
   ```

3. **Test Refunds**:
   ```javascript
   // In browser console
   const booking = new AppointmentBooking();
   await booking.init();
   await booking.handleUnconfirmedTimeout('appointment-id-here');
   ```

### Test Cron Jobs

```bash
# Locally test cron functions
curl -X POST http://localhost:3000/api/cron/check-confirmations
curl -X POST http://localhost:3000/api/cron/check-no-shows
```

## 📊 Monitoring & Analytics

### Key Metrics to Track

1. **Payment Success Rate**
   ```sql
   SELECT 
       COUNT(*) FILTER (WHERE payment_status = 'success') * 100.0 / COUNT(*) as success_rate
   FROM appointments
   WHERE created_at >= NOW() - INTERVAL '30 days';
   ```

2. **Confirmation Rate**
   ```sql
   SELECT 
       COUNT(*) FILTER (WHERE status = 'CONFIRMED') * 100.0 / 
       COUNT(*) FILTER (WHERE status IN ('PENDING_CONFIRMATION', 'CONFIRMED'))
       as confirmation_rate
   FROM appointments;
   ```

3. **No-Show Rate**
   ```sql
   SELECT 
       COUNT(*) FILTER (WHERE status = 'NO_SHOW') * 100.0 / 
       COUNT(*) FILTER (WHERE status IN ('COMPLETED', 'NO_SHOW'))
       as no_show_rate
   FROM appointments;
   ```

4. **Revenue Summary**
   ```sql
   SELECT * FROM payment_summary
   ORDER BY transaction_date DESC
   LIMIT 30;
   ```

## 🚨 Troubleshooting

### Payment Not Processing

**Check**:
1. Paystack keys are correct (test vs live)
2. Browser console for errors
3. Paystack dashboard for transaction status
4. Supabase logs for database errors

**Common Issues**:
- CORS errors → Check Vercel config
- Webhook not firing → Verify URL in Paystack dashboard
- Refund failing → Check transaction is at least 24h old (Paystack requirement)

### Appointment Not Updating

**Check**:
1. RLS policies allow the update
2. User is authenticated
3. Appointment status allows the transition
4. Check `appointment_logs` for error details

## 🌍 Scaling to Africa

### Multi-Currency Support

Modify `paystack-integration.js`:

```javascript
// Add currency detection
getCurrencyByCountry(country) {
    const currencies = {
        'ZA': 'ZAR',
        'NG': 'NGN',
        'KE': 'KES',
        'GH': 'GHS'
    };
    return currencies[country] || 'ZAR';
}
```

### Mobile Money Integration

Add M-Pesa, Airtel Money:

```javascript
// In payment initiation
metadata: {
    custom_fields: [
        {
            display_name: "Payment Method",
            variable_name: "payment_method",
            value: "mobile_money"
        }
    ]
}
```

## 📝 Next Steps

1. **Switch to Live Mode**:
   - Replace test keys with live keys
   - Test thoroughly in sandbox first
   - Update webhook URLs

2. **Add Email Notifications**:
   - Integrate SendGrid or Resend
   - Send confirmation emails
   - Send reminder emails

3. **Add SMS Notifications**:
   - Integrate Africa's Talking or Twilio
   - Send appointment reminders
   - Send payment receipts

4. **Practitioner Dashboard**:
   - Build practitioner portal
   - Allow confirmation/decline actions
   - View earnings and payouts

5. **Analytics Dashboard**:
   - Build admin panel
   - Track key metrics
   - Monitor refund rates

## 📞 Support

For issues or questions:
- Check Supabase logs
- Check Paystack dashboard
- Review `appointment_logs` table for audit trail

## ✅ Checklist Before Going Live

- [ ] Run `payment_appointments_schema.sql` in Supabase
- [ ] Replace test keys with live Paystack keys
- [ ] Configure webhook URL in Paystack dashboard
- [ ] Set up Vercel cron jobs
- [ ] Test complete payment flow with test cards
- [ ] Test refund flow
- [ ] Test cron jobs manually
- [ ] Set up monitoring/alerts
- [ ] Review and customize Terms & Conditions
- [ ] Add email/SMS notification integrations
- [ ] Test RLS policies with different user roles
- [ ] Configure backup/disaster recovery

---

**Built with ❤️ for African healthcare**
