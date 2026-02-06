# Complete Order Workflow & Notification System

## Overview
This document explains the complete order workflow from patient order to delivery, including payment processing, pharmacy management, driver notifications, and patient tracking.

---

## 📦 Order Status Flow

### 1. **Order Created** (`created`)
- **Trigger**: Patient places medication order
- **Payment Status**: `pending`
- **What Happens**:
  - Order saved to database with all items
  - Fee calculations stored (subtotal, delivery fee, platform fee, pharmacy amount, Paystack fee)
  - Patient redirected to Paystack payment

### 2. **Payment Completed** (`pending_confirmation`)
- **Trigger**: Patient completes Paystack payment
- **Payment Status**: `paid`
- **What Happens**:
  - Payment reference saved
  - Order status updated to `pending_confirmation`
  - Pharmacy receives notification to review order
  - Patient sees "Awaiting Pharmacy Confirmation"

### 3. **Pharmacy Confirms** (`confirmed`)
- **Trigger**: Pharmacy clicks "Confirm" button
- **What Happens**:
  - Order status → `confirmed`
  - Patient receives notification: "✅ Your order has been confirmed and is being prepared"
  - Pharmacy can now start processing

### 4. **Processing Medication** (`processing`)
- **Trigger**: Pharmacy clicks "Start Processing"
- **What Happens**:
  - Order status → `processing`
  - Patient receives notification: "🔄 Your medication is being processed"
  - Pharmacy prepares/packages the medication

### 5. **Ready for Delivery** (`ready_for_delivery`)
- **Trigger**: Pharmacy clicks "Mark Ready"
- **What Happens**:
  - Order status → `ready_for_delivery`
  - Patient receives notification: "📦 Your order is ready for delivery"
  - Pharmacy can now assign driver

### 6. **Driver Assigned** (`out_for_delivery`)
- **Trigger**: Pharmacy clicks "Assign Driver" and enters driver contact
- **What Happens**:
  - Order status → `out_for_delivery`
  - `driver_contact` saved to order
  - `delivery_started_at` timestamp recorded
  - Patient receives notification: "🚚 Your order is out for delivery"
  - Driver contact shown to patient
  - **Driver Notification**: Alert sent to driver with:
    - Pickup address (pharmacy)
    - Delivery address (patient)
    - Order number
    - Contact numbers

### 7. **Delivered** (`delivered`)
- **Trigger**: Driver/Pharmacy marks as delivered
- **What Happens**:
  - Order status → `delivered`
  - Patient receives notification: "✅ Your order has been delivered"
  - Patient can rate the order
  - Order marked complete

---

## 💰 Payment & Fee Structure

### Customer Pays:
```
Medication Subtotal:    R 167.00
Delivery Fee:           R  50.00
Paystack Fee (1.5% + R2): R   5.26
─────────────────────────────────
TOTAL PAID:             R 222.26
```

### Backend Distribution:
```
Paystack receives:      R   5.26  (processing fee)
Nrome receives:         R  16.70  (10% of R167 subtotal)
Pharmacy receives:      R 200.30  (R167 - R16.70 + R50 delivery)
```

### Database Fields (orders table):
- `subtotal`: R167.00 (medication only)
- `delivery_fee`: R50.00
- `paystack_fee`: R5.26
- `platform_fee`: R16.70 (10% of subtotal)
- `pharmacy_amount`: R200.30 (what pharmacy receives)
- `total_amount`: R222.26 (what customer paid)

---

## 🔔 Notification System

### Patient Notifications:
Patients receive notifications for:
- ✅ Order confirmed
- 🔄 Order processing
- 📦 Ready for delivery
- 🚚 Out for delivery (with driver contact)
- ✅ Delivered

### Pharmacy Notifications:
- 🛒 New order received (when payment completed)
- Prescription uploaded for review

### Driver Notifications:
- 📞 SMS/Email with pickup and delivery details
- Order number for reference
- Contact numbers (pharmacy + patient)

---

## 📱 Patient Order Tracking

### Features:
1. **Order List View**:
   - Progress bar showing order status
   - Payment status badge (PAID/UNPAID)
   - Item count and total amount
   - Delivery address
   - Track Order button

2. **Order Details Modal**:
   - **Visual Timeline**: Shows all steps from order placed to delivered
   - **Current Status**: Highlighted with icon and description
   - **Pharmacy Info**: Name, phone, address
   - **Delivery Info**: Name, phone, address
   - **Items List**: All medications with quantities and prices
   - **Fee Breakdown**: Subtotal, delivery, processing fee, total
   - **Driver Contact**: Shown when out for delivery
   - **Payment Reference**: Paystack transaction ID

3. **Actions Available**:
   - **Track Order**: Opens detailed tracking modal
   - **Cancel Order**: Available before delivery (requires confirmation)
   - **Complete Payment**: If payment pending
   - **Rate Order**: After delivery

---

## 🏪 Pharmacy Dashboard

### Order Management:
1. **Stats Cards**:
   - Pending Prescriptions
   - Active Orders (confirmed + processing)
   - Ready for Delivery
   - Completed Today

2. **Order List**:
   - Shows all orders for the pharmacy
   - Color-coded status badges
   - Payment status (PAID/UNPAID)
   - Fee breakdown (shows platform fee and net amount)

3. **Status Update Buttons** (context-aware):
   - **UNPAID**: "Awaiting Payment" (disabled)
   - **CREATED/PENDING_CONFIRMATION**: "Confirm" button
   - **CONFIRMED**: "Start Processing" button
   - **PROCESSING**: "Mark Ready" button
   - **READY_FOR_DELIVERY**: "Assign Driver" button
   - **OUT_FOR_DELIVERY**: "Driver En Route" status
   - **DELIVERED**: Complete

4. **Order Details View**:
   - Full order information
   - Items with quantities
   - Customer contact details
   - Fee breakdown (what pharmacy receives)
   - Confirm button (if pending)

---

## 🚗 Driver Assignment Process

### When Pharmacy Assigns Driver:
1. Pharmacy clicks "Assign Driver"
2. Prompt asks for driver email/phone
3. System updates order:
   - Status → `out_for_delivery`
   - Saves `driver_contact`
   - Records `delivery_started_at` timestamp
4. Alert shows pickup and delivery details
5. Patient receives notification with driver contact

### Driver Communication:
**Pickup Details**:
- Pharmacy name and address
- Order number
- Pharmacy contact number

**Delivery Details**:
- Patient name
- Patient phone
- Delivery address
- Order contents (medication count)

---

## 📊 Status Badge Colors

| Status | Color | Patient View | Pharmacy View |
|--------|-------|--------------|---------------|
| Created | Gray | "Order Placed" | "New Order" |
| Pending Confirmation | Yellow | "Awaiting Confirmation" | "CONFIRM" button |
| Confirmed | Green | "Confirmed" | "START PROCESSING" button |
| Processing | Blue | "Preparing Medication" | "MARK READY" button |
| Ready for Delivery | Light Blue | "Ready for Pickup" | "ASSIGN DRIVER" button |
| Out for Delivery | Blue | "Out for Delivery" | "Driver En Route" |
| Delivered | Green | "Delivered" | "Complete" |
| Cancelled | Red | "Cancelled" | "Cancelled" |

---

## 🗄️ Database Setup

### Required SQL Scripts:
1. **[add_order_fee_columns.sql](add_order_fee_columns.sql)**: Adds fee tracking columns
2. **[create_notifications_table.sql](create_notifications_table.sql)**: Creates notifications system

### Run in Supabase SQL Editor:
```sql
-- First, add fee columns
\i add_order_fee_columns.sql

-- Then, create notifications table
\i create_notifications_table.sql
```

---

## 🔐 Security (RLS)

### Orders Table:
- Patients can view/insert their own orders
- Pharmacies can view orders assigned to them
- Pharmacies can update status of their orders

### Notifications Table:
- Users can view/update/delete their own notifications
- System can insert notifications for any user

---

## 🎯 Next Steps for Production

1. **Email/SMS Integration**:
   - Send actual emails to drivers (not just alerts)
   - SMS notifications for delivery updates
   - Email receipts to patients

2. **Driver Portal**:
   - Dedicated driver login
   - View assigned deliveries
   - Update delivery status
   - Navigation integration

3. **Real-time Updates**:
   - Supabase Realtime subscriptions
   - Live order status updates without refresh

4. **Advanced Features**:
   - Order ratings and reviews
   - Delivery time estimates
   - GPS tracking
   - Photo proof of delivery

---

## 🐛 Troubleshooting

### "PENDING PAYMENT" showing when paid:
- Run [add_order_fee_columns.sql](add_order_fee_columns.sql) to add payment_status column
- Check payment callback is updating order correctly

### Fees showing R0.00:
- Run SQL to add fee columns
- Ensure `updateCart()` is called before order creation

### Driver not getting notified:
- Check driver_contact is being saved
- Implement email/SMS service for production

### Orders not showing in pharmacy dashboard:
- Verify pharmacy_id is set correctly in order
- Check RLS policies allow pharmacy to view orders
- Ensure pharmacy user has pharmacy_manager role
