# 🔄 NEW PRICING SYSTEM - VISUAL FLOW DIAGRAMS

## 💳 Payment Flow (5% Platform Fee)

```
┌─────────────────────────────────────────────────────────────┐
│                 PATIENT BOOKS APPOINTMENT                   │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│           PAYMENT CALCULATION (NEW 5% SYSTEM)               │
├─────────────────────────────────────────────────────────────┤
│  Consultation Fee:              R500.00                     │
│  Platform Fee (5%):             R25.00                      │
│  Paystack Processing Fee:       R9.00                       │
│  ─────────────────────────────────────────                  │
│  TOTAL PATIENT PAYS:            R534.00                     │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    PAYSTACK PAYMENT                         │
│                  (Secure Card Payment)                      │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                  PAYMENT DISTRIBUTION                       │
├─────────────────────────────────────────────────────────────┤
│  ✅ Practitioner receives:      R475.00 (95%)              │
│  ✅ Platform receives:          R25.00 (5%)                │
│  ✅ Paystack fee:               R9.00                       │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              APPOINTMENT STATUS: CONFIRMED                  │
└─────────────────────────────────────────────────────────────┘
```

---

## ⭐ Verification Badge Purchase Flow

```
┌─────────────────────────────────────────────────────────────┐
│         PRACTITIONER: "Get Verified Badge - R149"           │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                  BENEFITS DISPLAYED                         │
├─────────────────────────────────────────────────────────────┤
│  ⭐ Verified badge on profile                              │
│  🚀 AI recommends you FIRST                                │
│  📍 Top of all listings                                     │
│  💼 Build patient trust                                     │
│  📈 More bookings guaranteed                                │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│           PAYSTACK PAYMENT: R149.00 (Once-Off)              │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              DATABASE UPDATE                                │
├─────────────────────────────────────────────────────────────┤
│  verified_badge = true                                      │
│  badge_purchased_at = NOW()                                 │
│  badge_payment_reference = "BADGE_123..."                   │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              IMMEDIATE EFFECTS                              │
├─────────────────────────────────────────────────────────────┤
│  ✅ Badge appears on profile                               │
│  ✅ AI prioritizes in recommendations                       │
│  ✅ Appears first in all listings                           │
│  ✅ "Verified" status visible to patients                   │
└─────────────────────────────────────────────────────────────┘
```

---

## 🏥 Medical Aid Booking Fee Flow

```
┌─────────────────────────────────────────────────────────────┐
│    PATIENT BOOKS APPOINTMENT (Medical Aid Selected)         │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              PRACTITIONER ACCEPTS BOOKING                   │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│           AUTO-CHARGE R10 MEDICAL AID FEE                   │
├─────────────────────────────────────────────────────────────┤
│  medical_aid_fee_balance += R10                             │
│  can_accept_bookings = false                                │
│  New record in medical_aid_fees table                       │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              ⚠️ WARNING BANNER APPEARS                      │
├─────────────────────────────────────────────────────────────┤
│  "Outstanding Medical Aid Fees: R10.00"                     │
│  "Pay now to accept new bookings"                           │
│  [Pay R10 Now] button                                       │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│           PRACTITIONER CLICKS "Pay Now"                     │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│            PAYSTACK PAYMENT: R10.00                         │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              DATABASE UPDATE                                │
├─────────────────────────────────────────────────────────────┤
│  medical_aid_fee_balance = 0                                │
│  can_accept_bookings = true                                 │
│  All pending fees marked as "paid"                          │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│         ✅ BOOKING ACCEPTANCE RESUMED                       │
└─────────────────────────────────────────────────────────────┘
```

---

## 🤖 AI Recommendation Priority Flow

```
┌─────────────────────────────────────────────────────────────┐
│          PATIENT: "I need a doctor near me"                 │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              AI SEARCHES PRACTITIONERS                      │
│           (Location: Johannesburg example)                  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              SORT ALGORITHM (NEW)                           │
├─────────────────────────────────────────────────────────────┤
│  1. ⭐ VERIFIED PRACTITIONERS FIRST                         │
│     (regardless of location)                                │
│                                                              │
│  2. 📍 Then sort by distance                                │
│                                                              │
│  3. ⭐ Then by trust score                                  │
│                                                              │
│  4. 📅 Then by availability                                 │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              AI RECOMMENDATION LIST                         │
├─────────────────────────────────────────────────────────────┤
│  1. ⭐ Dr. Smith (Cape Town) - VERIFIED ✅                 │
│  2. ⭐ Dr. Jones (Durban) - VERIFIED ✅                    │
│  3. ⭐ Dr. Williams (Pretoria) - VERIFIED ✅               │
│  ─────────────────────────────────────────────              │
│  4. Dr. Brown (Johannesburg) - 2km away                     │
│  5. Dr. Davis (Johannesburg) - 5km away                     │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│   RESULT: Verified practitioners shown first,               │
│   even if they're 1000km away!                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔄 Complete Patient Journey (New System)

```
┌─────────────────────────────────────────────────────────────┐
│  Step 1: PATIENT BROWSES PRACTITIONERS                      │
├─────────────────────────────────────────────────────────────┤
│  • Sees verified badges (⭐ VERIFIED)                       │
│  • Verified practitioners at top of list                    │
│  • Consultation fees clearly displayed                      │
│  • Only "Book Appointment with AI" button                   │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  Step 2: PATIENT CLICKS "Book Appointment"                  │
├─────────────────────────────────────────────────────────────┤
│  • Opens booking modal                                      │
│  • Selects date & time                                      │
│  • Enters patient details                                   │
│  • [ ] Checks "Medical Aid" (optional)                      │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  Step 3: PAYMENT BREAKDOWN SHOWN                            │
├─────────────────────────────────────────────────────────────┤
│  Consultation Fee:         R500                             │
│  Platform Fee (5%):        R25                              │
│  Processing Fee:           R9                               │
│  ───────────────────────────────                            │
│  TOTAL:                    R534                             │
│                                                              │
│  Practitioner receives:    R475 (95%)                       │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  Step 4: PAYSTACK PAYMENT                                   │
├─────────────────────────────────────────────────────────────┤
│  • Secure card payment                                      │
│  • 3D Secure verification                                   │
│  • Payment reference generated                              │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  Step 5: CONFIRMATION                                       │
├─────────────────────────────────────────────────────────────┤
│  ✅ Appointment booked successfully                         │
│  📧 Confirmation email sent                                 │
│  📅 Added to patient's appointments                         │
│  🔔 Practitioner notified                                   │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  PARALLEL: IF MEDICAL AID BOOKING                           │
├─────────────────────────────────────────────────────────────┤
│  → Practitioner accepts booking                             │
│  → Auto-charge R10 fee to practitioner                      │
│  → Block new bookings until paid                            │
│  → Show payment warning                                     │
└─────────────────────────────────────────────────────────────┘
```

---

## 💰 Revenue Distribution (Example Month)

```
┌─────────────────────────────────────────────────────────────┐
│              EXAMPLE: 100 BOOKINGS/MONTH                    │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Total Consultation Fees:    100 × R500 = R50,000          │
│                                                              │
│  ┌────── DISTRIBUTION ──────┐                              │
│  │                          │                              │
│  │  PRACTITIONERS (95%):    │  R47,500                     │
│  │  • 100 payments          │  (Each gets R475)            │
│  │                          │                              │
│  │  PLATFORM (5%):          │  R2,500                      │
│  │  • Commission            │                              │
│  │                          │                              │
│  │  MEDICAL AID FEES:       │  R500                        │
│  │  • 50 bookings × R10     │                              │
│  │                          │                              │
│  │  VERIFICATION BADGES:    │  R2,980                      │
│  │  • 20 practitioners      │  (20 × R149)                 │
│  │                          │                              │
│  └──────────────────────────┘                              │
│                                                              │
│  TOTAL PLATFORM REVENUE:     R5,980                         │
│                                                              │
│  (vs Old System: R10,000 at 20%)                            │
│                                                              │
└─────────────────────────────────────────────────────────────┘

Key Insight:
• Platform revenue: -40% (R10k → R6k)
• BUT: More competitive for practitioners
• Attracts more practitioners to platform
• Volume increase compensates for lower %
• New revenue streams diversify income
```

---

## 🎯 Competitive Advantage

```
┌─────────────────────────────────────────────────────────────┐
│            NROME vs COMPETITORS                             │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  COMPETITOR A:                                              │
│  • 15% platform fee                                         │
│  • No verification badge                                    │
│  • Random practitioner sorting                              │
│                                                              │
│  COMPETITOR B:                                              │
│  • 20% platform fee                                         │
│  • Premium listing: R500/month                              │
│  • Manual prioritization                                    │
│                                                              │
│  NROME (NEW):                                               │
│  • ⭐ 5% platform fee (LOWEST!)                            │
│  • ⭐ Verification badge: R149 once-off                     │
│  • ⭐ AI-powered priority (automatic)                       │
│  • ⭐ Medical aid tracking                                  │
│  • ⭐ Smart payment blocking                                │
│                                                              │
│  RESULT: Most attractive platform for practitioners!        │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 📈 Growth Projection

```
Year 1 (Current - 20% fee):
├─ 100 practitioners
├─ 1,000 bookings/month
├─ R500,000 total fees
└─ R100,000 platform revenue (20%)

Year 2 (NEW - 5% fee):
├─ 500 practitioners (+400% growth from low fees!)
├─ 5,000 bookings/month
├─ R2,500,000 total fees
├─ Platform revenue breakdown:
│   ├─ Commission (5%):        R125,000
│   ├─ Medical aid fees:       R5,000
│   ├─ Verification badges:    R74,500 (500 × R149)
│   └─ TOTAL:                  R204,500
│
└─ Growth: +104% revenue despite lower %!

The Strategy: Attract mass adoption with low fees,
monetize through volume and value-added services.
```

---

**Created**: 2026-06-22  
**Status**: ✅ Ready for review  
**Next**: Implement UI components from diagrams
