# Medication Order Fee Structure

## Overview
This document explains how fees are calculated and distributed in the Nrome medication ordering system.

## Fee Components

### 1. **Medication Subtotal**
- Total cost of all medications in the order
- Example: R80.00 for medication items

### 2. **Delivery Fee**
- Fixed or variable delivery charge
- Currently set in `currentOrder.delivery_fee`
- Example: R50.00

### 3. **Paystack Processing Fee** (Customer Pays)
- **Formula**: `(Subtotal + Delivery Fee) × 1.5% + R2.00`
- This fee is **added to the customer's total**
- Example: `(R80.00 + R50.00) × 0.015 + R2.00 = R3.95`

### 4. **Nrome Platform Fee** (10% of Medication Subtotal)
- **Formula**: `Medication Subtotal × 10%`
- This fee is **deducted from pharmacy's portion**
- NOT shown to customer
- Example: `R80.00 × 0.10 = R8.00`

## Payment Breakdown Example

### Customer View:
```
Medication Subtotal:        R 80.00
Delivery Fee:               R 50.00
Paystack Processing Fee:    R  3.95
─────────────────────────────────
Total Amount to Pay:        R133.95
```

### Backend Distribution:
```
Customer Pays:              R133.95
├─ Paystack receives:       R  3.95 (processing fee)
├─ Nrome receives:          R  8.00 (10% platform fee)
└─ Pharmacy receives:       R122.00 (R130.00 - R8.00 platform fee)
```

### Detailed Calculation:
1. **Customer pays**: R133.95 total
2. **Paystack deducts**: R3.95 (processing fee)
3. **Remaining amount**: R130.00 (Subtotal R80 + Delivery R50)
4. **Nrome deducts**: R8.00 (10% of R80 medication subtotal)
5. **Pharmacy receives**: R122.00 (R130.00 - R8.00)

## Implementation Details

### Frontend (`medication.html`)
```javascript
// Fee calculation in updateCart()
currentOrder.paystack_fee = ((subtotal + delivery_fee) * 0.015) + 2.00;
currentOrder.platform_fee = subtotal * 0.10;
currentOrder.pharmacy_amount = subtotal - platform_fee;
currentOrder.total = subtotal + delivery_fee + paystack_fee;
```

### Database Fields (orders table)
- `subtotal`: Medication items total
- `delivery_fee`: Delivery charge
- `paystack_fee`: Processing fee (customer pays)
- `platform_fee`: Nrome's 10% commission
- `pharmacy_amount`: Amount pharmacy receives (subtotal - platform_fee)
- `total`: Total amount customer pays

## Customer Communication
The customer sees:
- ✅ Medication costs
- ✅ Delivery fee
- ✅ Paystack processing fee
- ✅ Total to pay

The customer does NOT see:
- ❌ Platform fee (10% commission)
- ❌ Pharmacy's net amount

## Pharmacy Dashboard
Pharmacies should see:
- Order subtotal (medication sales)
- Platform fee deducted (10%)
- Net payout amount
- Delivery fee (if pharmacy handles delivery)

## Notes
- Paystack fees are based on South African rates (1.5% + R2.00 for local cards)
- Platform fee is calculated on **medication subtotal only**, not delivery fee
- Delivery fee goes to pharmacy (or delivery partner if separate)
- All fees are calculated automatically in the `updateCart()` function
