# 💰 NEW PRICING STRUCTURE - 2026 UPDATE

## 📊 Pricing Packages

### FREE TIER
✅ Profile Listing  
✅ Receive Bookings  
✅ Medical Aid Bookings  
📝 **Platform Fee**: 5% on online payments only  
📝 **Medical Aid Fee**: R10 per successful medical aid booking  

### VERIFIED TIER (R149 once-off)
⭐ **Verification Badge** - Visual trust indicator  
⭐ **Practice Verification** - Admin-verified credentials  
⭐ **Medical Aid Verification** - Verified billing capability  
🚀 **AI Priority** - Always recommended first by AI  
📍 **Top of List** - Appears first regardless of location  
📝 **All Free Tier Benefits**  

---

## 🔄 Changes from Old System

| Feature | Old (20%) | New (5% + Fees) |
|---------|-----------|-----------------|
| **Online Payment Fee** | 20% | 5% |
| **Medical Aid Fee** | None | R10 per success |
| **Verification Badge** | None | R149 once-off |
| **AI Priority** | Location-based | Verified first, then location |

---

## 💳 Implementation Requirements

### 1. Update Platform Fee Calculation
**Current**:
```javascript
practitionerAmount = consultationFee * 0.8;  // 80%
platformAmount = consultationFee * 0.2;  // 20%
```

**New**:
```javascript
practitionerAmount = consultationFee * 0.95;  // 95%
platformAmount = consultationFee * 0.05;  // 5%
```

### 2. Add Medical Aid Booking Fee
**Logic**:
- When practitioner accepts medical aid booking → Charge R10  
- If unpaid → Block further bookings  
- Show payment banner: "Pay R10 to accept new medical aid bookings"

### 3. Add Verification Badge Purchase
**Database Changes**:
```sql
ALTER TABLE practitioners 
ADD COLUMN verified_badge BOOLEAN DEFAULT false,
ADD COLUMN badge_purchased_at TIMESTAMPTZ,
ADD COLUMN badge_payment_reference TEXT,
ADD COLUMN medical_aid_fee_balance INTEGER DEFAULT 0;
```

**Purchase Flow**:
1. Practitioner clicks "Upgrade to Verified"  
2. Paystack modal: R149 once-off payment  
3. On success → `verified_badge = true`  
4. Enable verification badge display  
5. Update AI recommendation logic

### 4. AI Priority Algorithm
**Current**: Sorts by distance first  
**New**: 
```javascript
// Sort order:
1. Verified practitioners (verified_badge = true)
2. Distance/location match
3. Trust score
4. Availability
```

---

## 📝 Files to Update

### 1. **nurse.html**
- Update fee calculation (lines ~2450-2500)
- Add medical aid fee check before booking acceptance
- Add "Upgrade to Verified" button
- Update AI sorting logic

### 2. **admin-pharmacy-review.html**
- Show verified badge status
- Admin toggle for verification

### 3. **Database Schema**
- Add new columns to `practitioners` table
- Create `verification_badge_payments` table
- Create `medical_aid_fees` table

### 4. **Paystack Integration**
- Add verification badge purchase handler
- Add medical aid fee payment handler

---

## 🎨 UI Elements

### Verified Badge Display
```html
<span class="badge bg-success">
    <i class="fas fa-check-circle"></i> Verified Practice
</span>
```

### Pricing Display in Appointment Summary
```html
<div class="pricing-breakdown">
    <div>Consultation Fee: R350</div>
    <div>Online Payment Fee (5%): R17.50</div>
    <hr>
    <div><strong>Total: R367.50</strong></div>
    <small class="text-muted">
        Practitioner receives: R332.50 (95%)
    </small>
</div>
```

### Medical Aid Fee Warning
```html
<div class="alert alert-warning">
    <i class="fas fa-exclamation-triangle"></i>
    <strong>Medical Aid Fee Required</strong>
    <p>Pay R10 to continue accepting medical aid bookings</p>
    <button onclick="payMedicalAidFee()">Pay R10 Now</button>
</div>
```

---

## 📊 Revenue Projection

**Example Scenario**:
- 100 online bookings @ R500 avg = R50,000
- Platform fee @ 5% = **R2,500**
- 50 medical aid bookings @ R10 = **R500**
- 20 verification badges @ R149 = **R2,980**
- **Total Platform Revenue**: R5,980

vs Old System:
- 100 bookings @ R500 = R50,000
- Platform fee @ 20% = **R10,000**
- **Difference**: -R4,020 but more competitive for practitioners

---

## ✅ Implementation Checklist

### Phase 1: Database (Run SQL)
- [ ] Add columns to practitioners table
- [ ] Create verification_badge_payments table
- [ ] Create medical_aid_fees table
- [ ] Add RLS policies

### Phase 2: Backend Logic
- [ ] Update fee calculation from 20% to 5%
- [ ] Add medical aid fee tracking
- [ ] Block bookings if medical aid fee unpaid
- [ ] Add verification badge purchase handler

### Phase 3: Frontend UI
- [ ] Update appointment booking fee display
- [ ] Add "Upgrade to Verified" button
- [ ] Add medical aid fee payment modal
- [ ] Display verified badge on profiles

### Phase 4: AI Logic
- [ ] Update recommendation algorithm
- [ ] Prioritize verified practitioners
- [ ] Sort verified first, then by location

### Phase 5: Testing
- [ ] Test 5% fee calculation
- [ ] Test medical aid fee blocking
- [ ] Test verification badge purchase
- [ ] Test AI priority sorting
- [ ] Test verified badge display

---

**Status**: ✏️ SPECIFICATION COMPLETE  
**Next**: Run SQL schema, update code  
**Generated**: June 22, 2026
