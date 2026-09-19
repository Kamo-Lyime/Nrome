# Practitioner Verification Flow Diagram

```
┌────────────────────────────────────────────────────────────────────────────┐
│                          NURSE.HTML - Main Page                            │
│                                                                            │
│  ┌──────────────────────────────────────────────────────────────────────┐ │
│  │              "All Available Registered Medical Practitioners"         │ │
│  │  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐                     │ │
│  │  │   Dr.  │  │   Dr.  │  │   Dr.  │  │   Dr.  │  [Verified ✓]       │ │
│  │  │ Johnson│  │  Brown │  │  Smith │  │  Davis │                      │ │
│  │  └────────┘  └────────┘  └────────┘  └────────┘                     │ │
│  └──────────────────────────────────────────────────────────────────────┘ │
│                                                                            │
│  ┌──────────────────────────────────────────────────────────────────────┐ │
│  │         🔵 [+ Register Your Medical Practice] Button                  │ │
│  │                                                                        │ │
│  │  CLICK ───────────────────────────────────────────────▼               │ │
│  │                                                                        │ │
│  │  ┌────────────────────────────────────────────────────────────────┐  │ │
│  │  │                   REGISTRATION WIZARD                          │  │ │
│  │  │                                                                │  │ │
│  │  │  ╔═══════════╗  ┌───────────┐  ┌───────────┐                  │  │ │
│  │  │  ║   STEP 1  ║  │   STEP 2  │  │   STEP 3  │                  │  │ │
│  │  │  ║  Profile  ║  │ Documents │  │  Review   │                  │  │ │
│  │  │  ╚═══════════╝  └───────────┘  └───────────┘                  │  │ │
│  │  │      ACTIVE        Inactive       Inactive                     │  │ │
│  │  │                                                                │  │ │
│  │  │  ┌──────────────────────────────────────────────────────────┐ │  │ │
│  │  │  │ STEP 1: PROFILE INFORMATION                              │ │  │ │
│  │  │  │                                                          │ │  │ │
│  │  │  │  📋 Full Name: _________________________________ *       │ │  │ │
│  │  │  │  👨‍⚕️ Profession: [▼ Dropdown] *                          │ │  │ │
│  │  │  │  📝 Registration #: _____________________________ *      │ │  │ │
│  │  │  │  🏥 Practice #: ______________________________           │ │  │ │
│  │  │  │  ⭐ Specialty: _________________________________         │ │  │ │
│  │  │  │  🏢 Practice Name: _____________________________         │ │  │ │
│  │  │  │  📍 Address: ___________________________________ *       │ │  │ │
│  │  │  │  💳 Medical Scheme: ⭕ Yes  ⭕ No *                       │ │  │ │
│  │  │  │                                                          │ │  │ │
│  │  │  │  [Cancel]              [Next: Upload Documents ➡️]      │ │  │ │
│  │  │  └──────────────────────────────────────────────────────────┘ │  │ │
│  │  └────────────────────────────────────────────────────────────────┘  │ │
│  └──────────────────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────────────────┘

                                    ⬇️ USER FILLS PROFILE + CLICKS "NEXT"

┌────────────────────────────────────────────────────────────────────────────┐
│                        STEP 1 DATA CAPTURED                                │
│  practitionerProfileData = {                                               │
│      full_name: "Dr. Sarah Johnson",                                       │
│      profession: "Medical Practitioner",                                   │
│      registration_number: "MP0123456",                                     │
│      practice_number: "1234567",                                           │
│      specialty: "General Practice",                                        │
│      practice_name: "Johnson Medical Centre",                              │
│      address: "123 Main St, Johannesburg",                                 │
│      medical_scheme_billing_supported: true                                │
│  }                                                                         │
└────────────────────────────────────────────────────────────────────────────┘

                                    ⬇️ NAVIGATE TO STEP 2

┌────────────────────────────────────────────────────────────────────────────┐
│                          NURSE.HTML - Main Page                            │
│                                                                            │
│  ┌──────────────────────────────────────────────────────────────────────┐ │
│  │         🔵 [− Close Registration Form] Button                         │ │
│  │                                                                        │ │
│  │  ┌────────────────────────────────────────────────────────────────┐  │ │
│  │  │                   REGISTRATION WIZARD                          │  │ │
│  │  │                                                                │  │ │
│  │  │  ┌───────────┐  ╔═══════════╗  ┌───────────┐                  │  │ │
│  │  │  │   STEP 1  │  ║   STEP 2  ║  │   STEP 3  │                  │  │ │
│  │  │  │  Profile  │  ║ Documents ║  │  Review   │                  │  │ │
│  │  │  └───────────┘  ╚═══════════╝  └───────────┘                  │  │ │
│  │  │    COMPLETED       ACTIVE        Inactive                      │  │ │
│  │  │       ✅                                                        │  │ │
│  │  │  ┌──────────────────────────────────────────────────────────┐ │  │ │
│  │  │  │ STEP 2: UPLOAD DOCUMENTS                                 │ │  │ │
│  │  │  │                                                          │ │  │ │
│  │  │  │  📄 1. ID Document *                                     │ │  │ │
│  │  │  │  ┌────────────────────────────────────────────────────┐ │ │  │ │
│  │  │  │  │  ☁️ Click or drag file here                        │ │ │  │ │
│  │  │  │  │     PDF, JPG, PNG (max 5MB)                        │ │ │  │ │
│  │  │  │  └────────────────────────────────────────────────────┘ │ │  │ │
│  │  │  │                                                          │ │  │ │
│  │  │  │  📜 2. Registration Certificate *                        │ │  │ │
│  │  │  │  ┌────────────────────────────────────────────────────┐ │ │  │ │
│  │  │  │  │  ✅ id_document.pdf (245 KB)          [🗑️ Remove] │ │ │  │ │
│  │  │  │  └────────────────────────────────────────────────────┘ │ │  │ │
│  │  │  │                                                          │ │  │ │
│  │  │  │  🎓 3. Degree Certificate *                             │ │  │ │
│  │  │  │  ┌────────────────────────────────────────────────────┐ │ │  │ │
│  │  │  │  │  ☁️ Click or drag file here                        │ │ │  │ │
│  │  │  │  └────────────────────────────────────────────────────┘ │ │  │ │
│  │  │  │                                                          │ │  │ │
│  │  │  │  🏠 4. Proof of Address *                               │ │  │ │
│  │  │  │  ┌────────────────────────────────────────────────────┐ │ │  │ │
│  │  │  │  │  ☁️ Click or drag file here                        │ │ │  │ │
│  │  │  │  └────────────────────────────────────────────────────┘ │ │  │ │
│  │  │  │                                                          │ │  │ │
│  │  │  │  [⬅️ Back]               [Next: Review ➡️] (disabled)  │ │  │ │
│  │  │  └──────────────────────────────────────────────────────────┘ │  │ │
│  │  └────────────────────────────────────────────────────────────────┘  │ │
│  └──────────────────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────────────────┘

              ⬇️ USER UPLOADS ALL 4 DOCUMENTS + CLICKS "NEXT"

┌────────────────────────────────────────────────────────────────────────────┐
│                       STEP 2 DOCUMENTS CAPTURED                            │
│  uploadedDocuments = {                                                     │
│      id_document: File {name: "id_document.pdf", size: 251234, ...},       │
│      registration_certificate: File {name: "reg_cert.pdf", ...},           │
│      degree_certificate: File {name: "degree.pdf", ...},                   │
│      proof_of_address: File {name: "proof.pdf", ...}                       │
│  }                                                                         │
└────────────────────────────────────────────────────────────────────────────┘

                                    ⬇️ NAVIGATE TO STEP 3

┌────────────────────────────────────────────────────────────────────────────┐
│                        REGISTRATION WIZARD - STEP 3                        │
│                                                                            │
│  ┌───────────┐  ┌───────────┐  ╔═══════════╗                             │
│  │   STEP 1  │  │   STEP 2  │  ║   STEP 3  ║                             │
│  │  Profile  │  │ Documents │  ║  Review   ║                             │
│  └───────────┘  └───────────┘  ╚═══════════╝                             │
│    COMPLETED     COMPLETED       ACTIVE                                    │
│       ✅             ✅                                                     │
│                                                                            │
│  ┌──────────────────────────────────────────────────────────────────────┐ │
│  │ STEP 3: REVIEW & SUBMIT                                              │ │
│  │                                                                      │ │
│  │  ╔════════════════════════════════════════════════════════════════╗ │ │
│  │  ║ 👤 PROFILE INFORMATION                                         ║ │ │
│  │  ╠════════════════════════════════════════════════════════════════╣ │ │
│  │  ║ Full Name: Dr. Sarah Johnson                                   ║ │ │
│  │  ║ Profession: Medical Practitioner                               ║ │ │
│  │  ║ Registration Number: MP0123456                                 ║ │ │
│  │  ║ Practice Number: 1234567                                       ║ │ │
│  │  ║ Specialty: General Practice                                    ║ │ │
│  │  ║ Practice Name: Johnson Medical Centre                          ║ │ │
│  │  ║ Medical Scheme Billing: Yes                                    ║ │ │
│  │  ║ Address: 123 Main St, Johannesburg, 2000                       ║ │ │
│  │  ╚════════════════════════════════════════════════════════════════╝ │ │
│  │                                                                      │ │
│  │  ╔════════════════════════════════════════════════════════════════╗ │ │
│  │  ║ 📁 UPLOADED DOCUMENTS                                          ║ │ │
│  │  ╠════════════════════════════════════════════════════════════════╣ │ │
│  │  ║ ✅ 4 documents uploaded                                        ║ │ │
│  │  ║ • ID Document: id_document.pdf                                 ║ │ │
│  │  ║ • Registration Certificate: reg_cert.pdf                       ║ │ │
│  │  ║ • Degree Certificate: degree.pdf                               ║ │ │
│  │  ║ • Proof of Address: proof.pdf                                  ║ │ │
│  │  ╚════════════════════════════════════════════════════════════════╝ │ │
│  │                                                                      │ │
│  │  ℹ️ WHAT HAPPENS NEXT?                                              │ │
│  │  1. Your application will be reviewed by our admin team             │ │
│  │  2. We'll verify your registration number with HPCSA/SANC           │ │
│  │  3. Our AI will analyze your documents for consistency              │ │
│  │  4. You'll receive email notification (typically 2-3 business days) │ │
│  │  5. After verification, you can start receiving patient bookings    │ │
│  │                                                                      │ │
│  │  [⬅️ Back]                 [📤 Submit for Verification] (green)    │ │
│  └──────────────────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────────────────┘

                    ⬇️ USER CLICKS "SUBMIT FOR VERIFICATION"

┌────────────────────────────────────────────────────────────────────────────┐
│                     SUBMISSION PROCESSING                                  │
│                                                                            │
│  🔄 Step 1: Upload Documents to Supabase Storage                          │
│     Bucket: verification-documents                                         │
│     ├─ user123_id_document_1234567890_id_document.pdf                     │
│     ├─ user123_registration_certificate_1234567891_reg_cert.pdf           │
│     ├─ user123_degree_certificate_1234567892_degree.pdf                   │
│     └─ user123_proof_of_address_1234567893_proof.pdf                      │
│                                                                            │
│  🔄 Step 2: Create Practitioner Record                                    │
│     INSERT INTO practitioners (user_id, full_name, profession, ...)       │
│     Status: "pending_documents"                                            │
│     ✅ practitioner.id = 42                                                │
│                                                                            │
│  🔄 Step 3: Create Document Records                                       │
│     INSERT INTO practitioner_documents (practitioner_id, doc_type, ...)   │
│     ├─ id_document → https://storage.supabase.co/.../id_doc.pdf           │
│     ├─ registration_certificate → https://storage.supabase.co/.../reg.pdf │
│     ├─ degree_certificate → https://storage.supabase.co/.../degree.pdf    │
│     └─ proof_of_address → https://storage.supabase.co/.../proof.pdf       │
│                                                                            │
│  🔄 Step 4: Create Verification Request                                   │
│     INSERT INTO verification_requests (practitioner_id, status, ...)      │
│     Status: "pending_review"                                               │
│     Submitted: 2025-01-11 14:32:15                                         │
│                                                                            │
│  ✅ SUBMISSION COMPLETE!                                                  │
└────────────────────────────────────────────────────────────────────────────┘

                                    ⬇️

┌────────────────────────────────────────────────────────────────────────────┐
│                         SUCCESS MESSAGE                                    │
│                                                                            │
│                            ✅                                              │
│                                                                            │
│                Application Submitted Successfully!                         │
│                                                                            │
│     Your practitioner verification application has been received.          │
│    You'll receive an email notification once our team reviews it.          │
│                                                                            │
│  ┌──────────────────────────────────────────────────────────────────────┐ │
│  │ Application Status: Pending Review                                   │ │
│  │ Submitted: 2025-01-11 14:32:15                                       │ │
│  └──────────────────────────────────────────────────────────────────────┘ │
│                                                                            │
│                          [❌ Close]                                        │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘

                    ⬇️ USER CLICKS "CLOSE" → FORM RESETS

┌────────────────────────────────────────────────────────────────────────────┐
│                  ADMIN REVIEW WORKFLOW                                     │
│                                                                            │
│  ADMIN OPENS: admin-pharmacy-review.html                                   │
│                                                                            │
│  ┌──────────────────────────────────────────────────────────────────────┐ │
│  │  [Pharmacies Tab]  [Practitioners Tab] ← CLICKED                     │ │
│  │                                                                        │ │
│  │  ┌────────────────────────────────────────────────────────────────┐  │ │
│  │  │ PENDING PRACTITIONER APPLICATIONS                              │  │ │
│  │  ├────────────┬──────────────┬────────────────┬──────────────────┤  │ │
│  │  │ Name       │ Profession   │ Status         │ Actions          │  │ │
│  │  ├────────────┼──────────────┼────────────────┼──────────────────┤  │ │
│  │  │ Dr. Sarah  │ Medical      │ Pending Review │ [Review] [Delete]│  │ │
│  │  │ Johnson    │ Practitioner │ (Yellow)       │                  │  │ │
│  │  └────────────┴──────────────┴────────────────┴──────────────────┘  │ │
│  └──────────────────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────────────────┘

                        ⬇️ ADMIN CLICKS "REVIEW"

┌────────────────────────────────────────────────────────────────────────────┐
│                       REVIEW MODAL                                         │
│                                                                            │
│  ╔════════════════════════════════════════════════════════════════════╗   │
│  ║ Review Practitioner Application - Dr. Sarah Johnson               ║   │
│  ╠════════════════════════════════════════════════════════════════════╣   │
│  ║                                                                    ║   │
│  ║ 📋 PROFILE INFORMATION                                            ║   │
│  ║ Full Name: Dr. Sarah Johnson                                      ║   │
│  ║ Profession: Medical Practitioner                                  ║   │
│  ║ Registration Number: MP0123456                                    ║   │
│  ║ Practice Number: 1234567                                          ║   │
│  ║                                                                    ║   │
│  ║ 📁 UPLOADED DOCUMENTS (Click to view)                             ║   │
│  ║ • [🔗 ID Document] ────────────────────────────► Opens in new tab ║   │
│  ║ • [🔗 Registration Certificate] ───────────────► Opens in new tab ║   │
│  ║ • [🔗 Degree Certificate] ──────────────────────► Opens in new tab ║   │
│  ║ • [🔗 Proof of Address] ────────────────────────► Opens in new tab ║   │
│  ║                                                                    ║   │
│  ║ ⭐ TRUST SCORE: 80/100                                            ║   │
│  ║ 🤖 AI VERIFICATION: 95% confidence                                ║   │
│  ║                                                                    ║   │
│  ║ ADMIN ACTIONS:                                                     ║   │
│  ║ [✅ Approve]  [❌ Reject]  [📧 Request More Info]  [Close]        ║   │
│  ╚════════════════════════════════════════════════════════════════════╝   │
└────────────────────────────────────────────────────────────────────────────┘

                        ⬇️ ADMIN CLICKS "APPROVE"

┌────────────────────────────────────────────────────────────────────────────┐
│                     VERIFICATION COMPLETE                                  │
│                                                                            │
│  UPDATE practitioners SET verification_status = 'verified' WHERE id = 42;  │
│  UPDATE verification_requests SET status = 'verified' WHERE ...            │
│                                                                            │
│  ✅ Dr. Sarah Johnson is now VERIFIED                                     │
│  ✅ Profile appears in "All Available Registered Medical Practitioners"   │
│  ✅ AI can recommend this practitioner to patients                        │
│  ✅ Can receive appointment bookings                                       │
│  📧 Email sent to practitioner: "Congratulations! You're verified"        │
└────────────────────────────────────────────────────────────────────────────┘

                                    ⬇️

┌────────────────────────────────────────────────────────────────────────────┐
│                  NURSE.HTML - VERIFIED PRACTITIONER                        │
│                                                                            │
│  ┌──────────────────────────────────────────────────────────────────────┐ │
│  │              "All Available Registered Medical Practitioners"         │ │
│  │  ┌───────────────┐  ┌────────┐  ┌────────┐  ┌────────┐             │ │
│  │  │ Dr. Sarah     │  │   Dr.  │  │   Dr.  │  │   Dr.  │             │ │
│  │  │ Johnson       │  │  Brown │  │  Smith │  │  Davis │             │ │
│  │  │ General       │  └────────┘  └────────┘  └────────┘             │ │
│  │  │ Practice      │                                                  │ │
│  │  │ [Verified ✅] │  ← NEW LISTING                                   │ │
│  │  │ Trust: 80/100 │                                                  │ │
│  │  └───────────────┘                                                  │ │
│  └──────────────────────────────────────────────────────────────────────┘ │
│                                                                            │
│  🤖 AI CHATBOT:                                                            │
│  Patient: "I need a general practitioner in Johannesburg"                 │
│  AI: "I recommend Dr. Sarah Johnson - verified practitioner,              │
│       specializing in general practice, located in Johannesburg."          │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

## Summary Flow

1. **User clicks "Register"** in nurse.html
2. **Step 1:** Fills profile information → Validates → Stores in JS
3. **Step 2:** Uploads 4 documents → Validates → Stores in JS
4. **Step 3:** Reviews summary → Clicks Submit
5. **Backend:** Uploads to Storage → Creates DB records → Success message
6. **Admin:** Reviews in admin dashboard → Views documents → Approves
7. **Result:** Practitioner verified → Appears in listings → AI recommends

## Key Features

✅ **3-Step Wizard** - Clear progression  
✅ **Drag & Drop** - Easy document upload  
✅ **Real-time Validation** - Prevents errors  
✅ **Review Summary** - See before submitting  
✅ **Supabase Integration** - Secure storage  
✅ **Admin Workflow** - Approve/reject/request  
✅ **AI Recommendations** - Location + specialty matching  
✅ **Trust Score** - 100-point verification system  
✅ **Auto-expiry** - 12-month reverification  

---

**File:** PRACTITIONER_VERIFICATION_FLOW_DIAGRAM.md  
**Updated:** January 2025
