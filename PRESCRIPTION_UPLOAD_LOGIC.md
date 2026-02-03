# 📋 PRESCRIPTION UPLOAD & ORDER ATTACHMENT LOGIC

## 🎯 Overview

The Nrome platform supports **TWO prescription upload scenarios** that integrate seamlessly with the medication ordering system:

1. **Patient Self-Upload** - Patients upload their own prescriptions
2. **Practitioner Upload** - Doctors/Clinicians upload prescriptions on behalf of patients

---

## 📤 SCENARIO 1: Patient Self-Upload

### Use Case
A patient visits a doctor offline, receives a physical/digital prescription, and wants to order medication through Nrome.

### Flow
```
Patient → Dashboard → Upload Prescription → Select Pharmacy → Order Medication → Attach Prescription
```

### Database Fields
```sql
prescriptions (
  patient_id = [patient's user ID],
  uploaded_by = [patient's user ID],  -- Same as patient_id
  upload_source = 'patient_upload',
  issued_by = NULL,  -- Unknown unless doctor is in system
  prescription_document_url = 'storage/prescriptions/patient123/rx001.pdf',
  status = 'pending_verification'
)
```

### Implementation Steps

1. **Patient uploads prescription file:**
   ```javascript
   const { data: uploadedFile } = await supabaseClient.storage
     .from('prescriptions')
     .upload(`${userId}/${Date.now()}_prescription.pdf`, file);
   ```

2. **Create prescription record:**
   ```javascript
   const { data: prescription } = await supabaseClient
     .from('prescriptions')
     .insert({
       prescription_number: `RX-${Date.now()}`,
       patient_id: currentUser.id,
       uploaded_by: currentUser.id,
       upload_source: 'patient_upload',
       issue_date: document.getElementById('prescriptionDate').value,
       valid_from: new Date(),
       valid_until: document.getElementById('expiryDate').value,
       prescription_document_url: uploadedFile.path,
       prescription_document_type: file.type,
       status: 'pending_verification',
       can_be_used_for_orders: true
     });
   ```

3. **Show in patient dashboard:**
   ```javascript
   // Load all prescriptions for the patient
   const { data: myPrescriptions } = await supabaseClient
     .from('prescriptions')
     .select('*')
     .eq('patient_id', currentUser.id)
     .order('created_at', { ascending: false });
   ```

4. **Attach to order:**
   ```javascript
   const { data: order } = await supabaseClient
     .from('orders')
     .insert({
       order_number: `NRM-${Date.now()}`,
       patient_id: currentUser.id,
       ordered_by: currentUser.id,
       pharmacy_id: selectedPharmacy.id,
       prescription_id: selectedPrescription.id,  // ← ATTACHMENT POINT
       is_prescription_order: true,
       status: 'rx_uploaded'
     });
   ```

---

## 🏥 SCENARIO 2: Practitioner Upload

### Use Case
A doctor/clinician creates a digital prescription in their clinic system and uploads it directly for the patient.

### Flow
```
Doctor → Clinic Portal → Create Prescription for Patient → System Auto-creates Prescription
Patient → Dashboard → Sees Prescription → Order Medication → Attach Prescription
```

### Database Fields
```sql
prescriptions (
  patient_id = [patient's user ID],
  uploaded_by = [doctor's user ID],  -- Different from patient_id
  upload_source = 'practitioner_upload',
  issued_by = [doctor's user ID],
  issued_from_clinic = [clinic ID],
  prescription_document_url = 'storage/prescriptions/clinic123/patient456/rx001.pdf',
  status = 'verified'  -- Can be pre-verified if from trusted source
)
```

### Implementation Steps

1. **Clinician uploads prescription:**
   ```javascript
   const { data: prescription } = await supabaseClient
     .from('prescriptions')
     .insert({
       prescription_number: `CLN-RX-${Date.now()}`,
       patient_id: selectedPatient.id,
       uploaded_by: currentClinician.id,
       issued_by: currentClinician.id,
       issued_from_clinic: currentClinic.id,
       upload_source: 'clinic_system',
       issue_date: new Date(),
       valid_from: new Date(),
       valid_until: calculateExpiryDate(),
       prescription_document_url: uploadedFile.path,
       status: 'pending_verification',  // Or 'verified' if clinic is trusted
       can_be_used_for_orders: true
     });
   ```

2. **Patient sees prescription in dashboard:**
   ```javascript
   // Patient sees ALL prescriptions (uploaded by them OR for them)
   const { data: allMyPrescriptions } = await supabaseClient
     .from('prescriptions')
     .select('*, uploaded_by:user_profiles!uploaded_by(full_name)')
     .eq('patient_id', currentUser.id);
   
   // Display shows who uploaded it
   allMyPrescriptions.forEach(rx => {
     if (rx.uploaded_by === currentUser.id) {
       console.log('You uploaded this');
     } else {
       console.log(`Uploaded by: ${rx.uploaded_by.full_name}`);
     }
   });
   ```

3. **Attach to order (same as patient upload):**
   ```javascript
   const { data: order } = await supabaseClient
     .from('orders')
     .insert({
       order_number: `NRM-${Date.now()}`,
       patient_id: currentUser.id,
       ordered_by: currentUser.id,
       pharmacy_id: selectedPharmacy.id,
       prescription_id: prescriptionFromDoctor.id,
       is_prescription_order: true,
       status: 'rx_uploaded'
     });
   ```

---

## 🔄 UNIFIED DASHBOARD LOGIC

### Dashboard Query (Shows ALL Prescriptions)
```javascript
async function loadPrescriptions() {
  const user = await getCurrentUser();
  
  const { data: prescriptions } = await supabaseClient
    .from('prescriptions')
    .select(`
      *,
      uploader:user_profiles!uploaded_by(full_name, email),
      issuer:user_profiles!issued_by(full_name),
      clinic:clinics(name),
      hospital:hospitals(name)
    `)
    .eq('patient_id', user.id)  // All prescriptions FOR this patient
    .order('created_at', { ascending: false });
  
  return prescriptions;
}
```

### Display Logic
```javascript
function displayPrescription(rx) {
  const uploadSource = rx.uploaded_by === currentUser.id 
    ? '<span class="badge bg-primary">Self-Uploaded</span>' 
    : `<span class="badge bg-success">Uploaded by ${rx.uploader.full_name}</span>`;
  
  const verificationStatus = rx.status === 'verified'
    ? '<span class="badge bg-success">Verified ✓</span>'
    : '<span class="badge bg-warning">Pending Verification</span>';
  
  const canUse = rx.can_be_used_for_orders && rx.status !== 'rejected'
    ? '<button onclick="attachToOrder(\'' + rx.id + '\')">Use for Order</button>'
    : '<span class="text-muted">Cannot be used</span>';
  
  return `
    <div class="prescription-card">
      <h6>${rx.prescription_number}</h6>
      ${uploadSource} ${verificationStatus}
      <p>Valid until: ${rx.valid_until}</p>
      ${canUse}
    </div>
  `;
}
```

---

## 🔗 ATTACHING PRESCRIPTION TO ORDER

### During Order Creation
```javascript
async function createOrderWithPrescription(prescriptionId) {
  // 1. Verify prescription is usable
  const { data: prescription } = await supabaseClient
    .from('prescriptions')
    .select('*')
    .eq('id', prescriptionId)
    .single();
  
  if (!prescription.can_be_used_for_orders) {
    alert('This prescription cannot be used for new orders');
    return;
  }
  
  if (prescription.status === 'rejected' || prescription.status === 'expired') {
    alert('This prescription is not valid');
    return;
  }
  
  // 2. Create order with prescription attached
  const { data: order } = await supabaseClient
    .from('orders')
    .insert({
      order_number: `NRM-${Date.now()}`,
      patient_id: currentUser.id,
      ordered_by: currentUser.id,
      pharmacy_id: selectedPharmacy.id,
      prescription_id: prescriptionId,  // ← LINK HERE
      is_prescription_order: true,
      delivery_address: deliveryAddress,
      status: prescription.status === 'verified' ? 'rx_verified' : 'rx_uploaded',
      subtotal: cartSubtotal,
      delivery_fee: deliveryFee,
      total_amount: total
    })
    .select()
    .single();
  
  // 3. Increment usage counter
  await supabaseClient
    .from('prescriptions')
    .update({ times_used: prescription.times_used + 1 })
    .eq('id', prescriptionId);
  
  // 4. Create order items from prescription items
  const { data: prescriptionItems } = await supabaseClient
    .from('prescription_items')
    .select('*')
    .eq('prescription_id', prescriptionId);
  
  for (const item of prescriptionItems) {
    await supabaseClient
      .from('order_items')
      .insert({
        order_id: order.id,
        medication_id: item.medication_id,
        medication_name: item.medication_name,
        medication_type: 'prescription',
        quantity: item.quantity,
        prescription_item_id: item.id
      });
  }
  
  return order;
}
```

---

## 🔐 PERMISSIONS & RLS

### Who Can See What?

| Role | Can View | Can Upload | Can Verify | Can Attach to Order |
|------|----------|------------|------------|---------------------|
| **Patient** | Own prescriptions (uploaded by them OR for them) | ✅ For themselves | ❌ | ✅ Own prescriptions |
| **Caregiver** | Patient's prescriptions (if authorized) | ❌ | ❌ | ✅ For patient |
| **Clinician** | Prescriptions they issued/uploaded | ✅ For patients | ❌ | ❌ |
| **Pharmacist** | Prescriptions linked to orders at their pharmacy | ❌ | ✅ | ❌ |
| **Admin** | All prescriptions | ✅ Any | ✅ | ❌ |

### RLS Policy Examples

**Patient viewing prescriptions:**
```sql
CREATE POLICY prescriptions_select_patient
  ON prescriptions FOR SELECT
  USING (patient_id = auth.uid() OR uploaded_by = auth.uid());
```

**Clinician uploading for patient:**
```sql
CREATE POLICY prescriptions_insert_clinician
  ON prescriptions FOR INSERT
  WITH CHECK (
    has_role('clinician') AND 
    uploaded_by = auth.uid()
  );
```

**Pharmacist verifying:**
```sql
CREATE POLICY prescriptions_update_pharmacist
  ON prescriptions FOR UPDATE
  USING (
    has_role('pharmacist') AND
    id IN (
      SELECT prescription_id FROM orders
      WHERE pharmacy_id IN (
        SELECT organization_id FROM user_role_assignments
        WHERE user_id = auth.uid() AND role = 'pharmacist'
      )
    )
  );
```

---

## 📊 STATE MACHINE INTEGRATION

### Order Status Flow with Prescription

```
OTC Order (No Prescription):
Created → Prepared → Driver Assigned → Picked Up → Delivered → Closed

Prescription Order (Patient Upload):
Created → Rx Uploaded → Rx Verified → Prepared → Driver Assigned → Picked Up → Delivered → Closed
           ↑ Upload    ↑ Pharmacist
           
Prescription Order (Clinician Upload - Pre-verified):
Created → Rx Verified → Prepared → Driver Assigned → Picked Up → Delivered → Closed
           ↑ Already verified by trusted source
```

### Prescription Status Impact on Order

| Prescription Status | Can Attach to Order? | Order Status After Attachment |
|---------------------|----------------------|-------------------------------|
| `pending_verification` | ✅ Yes | `rx_uploaded` |
| `verified` | ✅ Yes | `rx_verified` (skip to next step) |
| `rejected` | ❌ No | N/A |
| `expired` | ❌ No | N/A |

---

## 🚀 IMPLEMENTATION CHECKLIST

### Frontend (medication.html)

- [x] Upload prescription form (patient)
- [x] Dashboard showing all prescriptions (patient + practitioner)
- [x] Filter/badge showing upload source
- [x] Attach prescription to order flow
- [ ] Prescription preview modal
- [ ] Upload progress indicator
- [ ] Validation for file types/sizes

### Backend (Supabase)

- [x] Prescriptions table with `uploaded_by` field
- [x] RLS policies for patient and practitioner uploads
- [x] Storage bucket for prescription files
- [x] Prescription-order relationship
- [x] Usage counter and validation

### Business Logic

- [x] Prescription reuse limit (repeats_allowed)
- [x] Expiry date validation
- [x] Pharmacist verification requirement
- [x] State machine integration
- [ ] Notification when practitioner uploads prescription
- [ ] Email confirmation to patient

---

## 💡 EXAMPLE SCENARIOS

### Scenario A: Patient Orders with Self-Uploaded Prescription
1. Patient uploads prescription → `status: pending_verification`
2. Patient creates order, attaches prescription → Order `status: rx_uploaded`
3. Pharmacist verifies prescription → Prescription `status: verified`, Order `status: rx_verified`
4. Pharmacist prepares medication → Order `status: prepared`
5. Continue normal flow...

### Scenario B: Patient Orders with Doctor-Uploaded Prescription
1. Doctor uploads prescription for patient → `status: verified` (trusted source)
2. Patient sees prescription in dashboard
3. Patient creates order, attaches prescription → Order `status: rx_verified` (skip rx_uploaded)
4. Pharmacist prepares medication → Order `status: prepared`
5. Continue normal flow...

### Scenario C: Patient Reuses Existing Prescription
1. Patient has verified prescription with `repeats_allowed: 2`, `times_used: 0`
2. Patient creates first order → `times_used: 1`
3. Patient creates second order with same prescription → `times_used: 2`
4. Patient tries third order → System blocks (repeats exhausted)

---

## 🎯 Key Features

✅ **Dual Upload Source** - Patient or practitioner  
✅ **Unified Dashboard** - All prescriptions in one place  
✅ **Flexible Attachment** - Attach any valid prescription to order  
✅ **Usage Tracking** - Monitor prescription reuse  
✅ **Automatic Verification** - Skip step if from trusted source  
✅ **Expiry Management** - Auto-block expired prescriptions  
✅ **Audit Trail** - Track who uploaded what and when  

This logic ensures seamless integration between prescription management and medication ordering! 🚀
