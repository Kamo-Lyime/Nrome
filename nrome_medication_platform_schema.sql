-- ============================================================================
-- NROME MEDICATION DELIVERY PLATFORM - FULL SQL SCHEMA
-- South African Regulatory-Ready (SAPC, POPIA Compliant)
-- ============================================================================
-- Platform: Supabase PostgreSQL
-- Date: February 3, 2026
-- Description: Complete end-to-end medication delivery orchestration layer
-- ============================================================================

-- ============================================================================
-- CLEANUP: Drop tables with potential schema conflicts (run first)
-- ============================================================================

-- Drop tables in reverse dependency order to avoid foreign key errors
DROP TABLE IF EXISTS prescription_items CASCADE;
DROP TABLE IF EXISTS prescriptions CASCADE;

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- ============================================================================
-- ENUMS (Type Safety & State Management)
-- ============================================================================

-- User Roles (RBAC Foundation)
DO $$ BEGIN
  CREATE TYPE user_role AS ENUM (
    'patient',
    'caregiver',
    'pharmacist',
    'clinician',
    'driver',
    'admin',
    'pharmacy_manager',
    'clinic_manager',
    'hospital_manager'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Order States (Strict State Machine - NO SKIPPING)
DO $$ BEGIN
  CREATE TYPE order_status AS ENUM (
    'created',
    'rx_uploaded',
    'rx_verified',
    'prepared',
    'driver_assigned',
    'picked_up',
    'out_for_delivery',
    'delivered',
    'closed',
    'cancelled',
    'rx_rejected'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Medication Types
DO $$ BEGIN
  CREATE TYPE medication_type AS ENUM (
    'otc',              -- Over The Counter
    'prescription',     -- Requires Rx
    'schedule_1',       -- Controlled (lowest)
    'schedule_2',
    'schedule_3',
    'schedule_4',
    'schedule_5',
    'schedule_6',       -- Controlled (highest)
    'chronic'           -- Chronic medication
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Prescription Status
DO $$ BEGIN
  CREATE TYPE prescription_status AS ENUM (
    'pending_verification',
    'verified',
    'rejected',
    'expired',
    'fulfilled',
    'partially_fulfilled'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Delivery Proof Types
DO $$ BEGIN
  CREATE TYPE proof_type AS ENUM (
    'otp',
    'signature',
    'id_check',
    'photo'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Organization Types
DO $$ BEGIN
  CREATE TYPE organization_type AS ENUM (
    'pharmacy',
    'clinic',
    'hospital'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Payment Status
DO $$ BEGIN
  CREATE TYPE payment_status AS ENUM (
    'pending',
    'processing',
    'successful',
    'failed',
    'refunded',
    'partially_refunded'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Chronic Enrollment Status
DO $$ BEGIN
  CREATE TYPE chronic_status AS ENUM (
    'pending_approval',
    'active',
    'paused',
    'cancelled',
    'expired'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- Message Types (Restricted Communication)
DO $$ BEGIN
  CREATE TYPE message_type AS ENUM (
    'patient_driver',
    'patient_pharmacy',
    'patient_clinic',
    'patient_hospital',
    'system'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- ============================================================================
-- CORE USER TABLES
-- ============================================================================

-- User Profiles (Extends Supabase Auth)
CREATE TABLE IF NOT EXISTS user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  id_number TEXT UNIQUE,  -- SA ID Number (POPIA protected)
  phone_number TEXT NOT NULL,
  email TEXT NOT NULL,
  date_of_birth DATE,
  gender TEXT CHECK (gender IN ('male', 'female', 'other', 'prefer_not_to_say')),
  
  -- Address
  street_address TEXT,
  suburb TEXT,
  city TEXT,
  province TEXT,
  postal_code TEXT,
  country TEXT DEFAULT 'South Africa',
  
  -- Geolocation for delivery
  latitude DECIMAL(10, 8),
  longitude DECIMAL(11, 8),
  
  -- POPIA Compliance
  consent_given BOOLEAN DEFAULT FALSE,
  consent_date TIMESTAMPTZ,
  marketing_consent BOOLEAN DEFAULT FALSE,
  
  -- Metadata
  profile_complete BOOLEAN DEFAULT FALSE,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- User Roles (Many-to-Many - Users can have multiple roles)
CREATE TABLE IF NOT EXISTS user_role_assignments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
  role user_role NOT NULL,
  organization_id UUID,  -- Links to pharmacy/clinic/hospital if applicable
  is_active BOOLEAN DEFAULT TRUE,
  assigned_at TIMESTAMPTZ DEFAULT NOW(),
  assigned_by UUID REFERENCES user_profiles(id),
  UNIQUE(user_id, role, organization_id)
);

-- Caregivers (Patient-Caregiver Relationship)
CREATE TABLE IF NOT EXISTS caregivers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  patient_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
  caregiver_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
  relationship TEXT,  -- e.g., "spouse", "parent", "nurse"
  can_order BOOLEAN DEFAULT FALSE,
  can_track BOOLEAN DEFAULT TRUE,
  can_receive BOOLEAN DEFAULT TRUE,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(patient_id, caregiver_id)
);

-- ============================================================================
-- ORGANIZATION TABLES (Pharmacies, Clinics, Hospitals)
-- ============================================================================

-- Pharmacies (Licensed Dispensers)
CREATE TABLE IF NOT EXISTS pharmacies (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  sapc_number TEXT UNIQUE NOT NULL,  -- South African Pharmacy Council Registration
  license_expiry DATE NOT NULL,
  
  -- Contact
  phone TEXT NOT NULL,
  email TEXT NOT NULL,
  
  -- Address
  street_address TEXT NOT NULL,
  suburb TEXT,
  city TEXT NOT NULL,
  province TEXT NOT NULL,
  postal_code TEXT,
  
  -- Geolocation
  latitude DECIMAL(10, 8),
  longitude DECIMAL(11, 8),
  
  -- Operating Hours (JSON)
  operating_hours JSONB,  -- e.g., {"monday": {"open": "08:00", "close": "18:00"}}
  
  -- Capabilities
  chronic_meds_available BOOLEAN DEFAULT TRUE,
  schedule_meds_available BOOLEAN DEFAULT FALSE,
  delivery_available BOOLEAN DEFAULT TRUE,
  
  -- Payment
  paystack_subaccount_code TEXT,  -- For payment splits
  bank_account_number TEXT,
  bank_name TEXT,
  
  -- Status
  is_verified BOOLEAN DEFAULT FALSE,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Clinics (Issue Prescriptions Only)
CREATE TABLE IF NOT EXISTS clinics (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  practice_number TEXT UNIQUE,
  
  -- Contact
  phone TEXT NOT NULL,
  email TEXT NOT NULL,
  
  -- Address
  street_address TEXT NOT NULL,
  suburb TEXT,
  city TEXT NOT NULL,
  province TEXT NOT NULL,
  postal_code TEXT,
  
  -- Geolocation
  latitude DECIMAL(10, 8),
  longitude DECIMAL(11, 8),
  
  -- Operating Hours
  operating_hours JSONB,
  
  -- Specialty
  specialties TEXT[],
  
  -- Status
  is_verified BOOLEAN DEFAULT FALSE,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Hospitals (Discharge Meds, Long-term Care)
CREATE TABLE IF NOT EXISTS hospitals (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  hospital_registration_number TEXT UNIQUE,
  hospital_type TEXT,  -- 'public', 'private', 'provincial'
  
  -- Contact
  phone TEXT NOT NULL,
  email TEXT NOT NULL,
  emergency_phone TEXT,
  
  -- Address
  street_address TEXT NOT NULL,
  suburb TEXT,
  city TEXT NOT NULL,
  province TEXT NOT NULL,
  postal_code TEXT,
  
  -- Geolocation
  latitude DECIMAL(10, 8),
  longitude DECIMAL(11, 8),
  
  -- Capabilities
  chronic_program_available BOOLEAN DEFAULT TRUE,
  discharge_prescription_digital BOOLEAN DEFAULT TRUE,
  
  -- Status
  is_verified BOOLEAN DEFAULT FALSE,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- MEDICATION & PRESCRIPTION TABLES
-- ============================================================================

-- Medication Catalog
CREATE TABLE IF NOT EXISTS medications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  generic_name TEXT,
  medication_type medication_type NOT NULL,
  schedule_classification TEXT,  -- SA Schedule classification
  
  -- Identifiers
  nappi_code TEXT UNIQUE,  -- South African NAPPI code
  barcode TEXT,
  
  -- Details
  strength TEXT,
  dosage_form TEXT,  -- tablet, capsule, syrup, etc.
  manufacturer TEXT,
  active_ingredients TEXT[],
  
  -- Pricing (indicative - actual from pharmacy)
  indicative_price DECIMAL(10, 2),
  
  -- Flags
  requires_prescription BOOLEAN DEFAULT FALSE,
  requires_id_on_delivery BOOLEAN DEFAULT FALSE,
  is_chronic_eligible BOOLEAN DEFAULT FALSE,
  
  -- Status
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Prescriptions (Digital Rx)
-- SUPPORTS TWO UPLOAD SCENARIOS:
-- 1. Patient uploads their own prescription (uploaded_by = patient_id)
-- 2. Medical practitioner uploads prescription for patient (uploaded_by = clinician/doctor)
CREATE TABLE IF NOT EXISTS prescriptions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  prescription_number TEXT UNIQUE NOT NULL,
  
  -- Patient (Always required - who the prescription is FOR)
  patient_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
  
  -- Upload Source (Who uploaded the prescription)
  uploaded_by UUID NOT NULL REFERENCES user_profiles(id),  -- Can be patient OR practitioner
  uploaded_at TIMESTAMPTZ DEFAULT NOW(),
  upload_source TEXT CHECK (upload_source IN ('patient_upload', 'practitioner_upload', 'clinic_system', 'hospital_system')),
  
  -- Issuer (Clinician who WROTE the prescription - may differ from uploader)
  issued_by UUID REFERENCES user_profiles(id),  -- Clinician/Doctor
  issued_from_clinic UUID REFERENCES clinics(id),
  issued_from_hospital UUID REFERENCES hospitals(id),
  issue_date DATE NOT NULL,
  
  -- Prescription Details
  diagnosis TEXT,
  special_instructions TEXT,
  
  -- Document
  prescription_document_url TEXT,  -- Uploaded image/PDF (stored in Supabase Storage)
  prescription_document_type TEXT,  -- 'image/jpeg', 'application/pdf'
  
  -- Validity
  valid_from DATE NOT NULL,
  valid_until DATE NOT NULL,
  repeats_allowed INTEGER DEFAULT 0,
  repeats_used INTEGER DEFAULT 0,
  
  -- Verification (By Pharmacist - MANDATORY before dispensing)
  status prescription_status DEFAULT 'pending_verification',
  verified_by UUID REFERENCES user_profiles(id),  -- Pharmacist
  verified_at TIMESTAMPTZ,
  verification_notes TEXT,
  rejection_reason TEXT,
  
  -- Metadata
  is_chronic BOOLEAN DEFAULT FALSE,
  is_discharge BOOLEAN DEFAULT FALSE,
  is_locked BOOLEAN DEFAULT FALSE,  -- Locked after verification - immutable
  can_be_used_for_orders BOOLEAN DEFAULT TRUE,  -- If false, prescription cannot be attached to new orders
  times_used INTEGER DEFAULT 0,  -- How many orders have used this prescription
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Constraints
  CHECK (issued_from_clinic IS NOT NULL OR issued_from_hospital IS NOT NULL OR issued_by IS NOT NULL)
);

-- Prescription Items (Medications on a Prescription)
CREATE TABLE IF NOT EXISTS prescription_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  prescription_id UUID NOT NULL REFERENCES prescriptions(id) ON DELETE CASCADE,
  medication_id UUID REFERENCES medications(id),
  
  -- Details
  medication_name TEXT NOT NULL,  -- In case not in catalog
  dosage TEXT NOT NULL,
  frequency TEXT NOT NULL,
  duration TEXT,
  quantity INTEGER NOT NULL,
  
  -- Fulfillment
  quantity_dispensed INTEGER DEFAULT 0,
  is_fulfilled BOOLEAN DEFAULT FALSE,
  
  -- Instructions
  special_instructions TEXT,
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Chronic Medication Enrollments
CREATE TABLE IF NOT EXISTS chronic_enrollments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Patient
  patient_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
  
  -- Source
  prescription_id UUID NOT NULL REFERENCES prescriptions(id),
  enrolled_by_pharmacy UUID REFERENCES pharmacies(id),
  enrolled_by_clinic UUID REFERENCES clinics(id),
  enrolled_by_hospital UUID REFERENCES hospitals(id),
  
  -- Medication
  medication_id UUID REFERENCES medications(id),
  medication_name TEXT NOT NULL,
  dosage TEXT NOT NULL,
  frequency TEXT NOT NULL,
  monthly_quantity INTEGER NOT NULL,
  
  -- Schedule
  delivery_day_of_month INTEGER CHECK (delivery_day_of_month BETWEEN 1 AND 28),
  next_delivery_date DATE,
  
  -- Status
  status chronic_status DEFAULT 'pending_approval',
  approved_by UUID REFERENCES user_profiles(id),  -- Pharmacist/Admin
  approved_at TIMESTAMPTZ,
  
  -- Pause Management
  paused_until DATE,
  pause_reason TEXT,
  
  -- Validity
  start_date DATE NOT NULL,
  end_date DATE,
  refills_remaining INTEGER,
  
  -- Delivery Address (can differ from profile)
  delivery_address TEXT,
  delivery_latitude DECIMAL(10, 8),
  delivery_longitude DECIMAL(11, 8),
  
  -- Metadata
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(patient_id, prescription_id, medication_id)
);

-- ============================================================================
-- ORDER TABLES (State Machine)
-- ============================================================================

-- Orders (Primary Transaction)
CREATE TABLE IF NOT EXISTS orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_number TEXT UNIQUE NOT NULL,
  
  -- Patient
  patient_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
  ordered_by UUID NOT NULL REFERENCES user_profiles(id),  -- Can be caregiver
  
  -- Source
  pharmacy_id UUID REFERENCES pharmacies(id),
  clinic_id UUID REFERENCES clinics(id),
  hospital_id UUID REFERENCES hospitals(id),
  chronic_enrollment_id UUID REFERENCES chronic_enrollments(id),
  
  -- Order Type
  is_prescription_order BOOLEAN DEFAULT FALSE,
  is_otc_order BOOLEAN DEFAULT FALSE,
  is_chronic_order BOOLEAN DEFAULT FALSE,
  is_discharge_order BOOLEAN DEFAULT FALSE,
  
  -- Prescription (if applicable)
  prescription_id UUID REFERENCES prescriptions(id),
  
  -- Delivery Address
  delivery_address TEXT NOT NULL,
  delivery_suburb TEXT,
  delivery_city TEXT,
  delivery_province TEXT,
  delivery_postal_code TEXT,
  delivery_latitude DECIMAL(10, 8),
  delivery_longitude DECIMAL(11, 8),
  
  -- Contact
  delivery_contact_name TEXT NOT NULL,
  delivery_contact_phone TEXT NOT NULL,
  
  -- Status (STATE MACHINE)
  status order_status DEFAULT 'created',
  
  -- Pricing
  subtotal DECIMAL(10, 2) DEFAULT 0,
  delivery_fee DECIMAL(10, 2) DEFAULT 0,
  total_amount DECIMAL(10, 2) DEFAULT 0,
  
  -- Payment
  payment_status payment_status DEFAULT 'pending',
  paid_at TIMESTAMPTZ,
  
  -- Special Instructions
  delivery_instructions TEXT,
  requires_id_verification BOOLEAN DEFAULT FALSE,
  
  -- Timestamps (Audit Trail)
  created_at TIMESTAMPTZ DEFAULT NOW(),
  rx_uploaded_at TIMESTAMPTZ,
  rx_verified_at TIMESTAMPTZ,
  prepared_at TIMESTAMPTZ,
  driver_assigned_at TIMESTAMPTZ,
  picked_up_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  closed_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  
  -- Cancellation
  cancellation_reason TEXT,
  cancelled_by UUID REFERENCES user_profiles(id),
  
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Order Items
CREATE TABLE IF NOT EXISTS order_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  
  -- Medication
  medication_id UUID REFERENCES medications(id),
  medication_name TEXT NOT NULL,
  medication_type medication_type NOT NULL,
  
  -- Quantity & Pricing
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  unit_price DECIMAL(10, 2) NOT NULL,
  total_price DECIMAL(10, 2) NOT NULL,
  
  -- Prescription Item Link
  prescription_item_id UUID REFERENCES prescription_items(id),
  
  -- Dispensing (filled by pharmacy)
  dispensed_quantity INTEGER DEFAULT 0,
  dispensed_by UUID REFERENCES user_profiles(id),  -- Pharmacist
  dispensed_at TIMESTAMPTZ,
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Order Status History (Immutable Audit Log)
CREATE TABLE IF NOT EXISTS order_status_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  
  -- Status Change
  from_status order_status,
  to_status order_status NOT NULL,
  
  -- Actor
  changed_by UUID REFERENCES user_profiles(id),
  actor_role user_role,
  
  -- Notes
  notes TEXT,
  system_generated BOOLEAN DEFAULT FALSE,
  
  -- Metadata
  ip_address INET,
  user_agent TEXT,
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- DELIVERY TABLES
-- ============================================================================

-- Drivers (Delivery Personnel)
CREATE TABLE IF NOT EXISTS drivers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL UNIQUE REFERENCES user_profiles(id) ON DELETE CASCADE,
  
  -- Vehicle
  vehicle_type TEXT,  -- 'bike', 'motorcycle', 'car'
  vehicle_registration TEXT,
  
  -- License
  drivers_license_number TEXT,
  license_expiry DATE,
  
  -- Background Check
  background_check_verified BOOLEAN DEFAULT FALSE,
  background_check_date DATE,
  
  -- Status
  is_available BOOLEAN DEFAULT FALSE,
  current_latitude DECIMAL(10, 8),
  current_longitude DECIMAL(11, 8),
  last_location_update TIMESTAMPTZ,
  
  -- Performance
  total_deliveries INTEGER DEFAULT 0,
  successful_deliveries INTEGER DEFAULT 0,
  average_rating DECIMAL(3, 2),
  
  -- Metadata
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Deliveries
CREATE TABLE IF NOT EXISTS deliveries (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID NOT NULL UNIQUE REFERENCES orders(id) ON DELETE CASCADE,
  
  -- Driver Assignment
  driver_id UUID REFERENCES drivers(id),
  assigned_at TIMESTAMPTZ,
  assigned_by UUID REFERENCES user_profiles(id),
  
  -- Pharmacy Pickup
  pharmacy_id UUID NOT NULL REFERENCES pharmacies(id),
  pickup_address TEXT NOT NULL,
  pickup_latitude DECIMAL(10, 8),
  pickup_longitude DECIMAL(11, 8),
  
  -- Patient Delivery
  delivery_address TEXT NOT NULL,
  delivery_latitude DECIMAL(10, 8),
  delivery_longitude DECIMAL(11, 8),
  
  -- Times
  estimated_pickup_time TIMESTAMPTZ,
  actual_pickup_time TIMESTAMPTZ,
  estimated_delivery_time TIMESTAMPTZ,
  actual_delivery_time TIMESTAMPTZ,
  
  -- Tracking
  current_status TEXT DEFAULT 'pending',  -- 'pending', 'en_route_to_pharmacy', 'picked_up', 'en_route_to_patient', 'delivered'
  
  -- Distance
  distance_km DECIMAL(10, 2),
  
  -- Delivery Fee
  delivery_fee DECIMAL(10, 2),
  driver_earnings DECIMAL(10, 2),
  
  -- Contact (Driver sees LIMITED info)
  contact_name TEXT NOT NULL,
  contact_phone TEXT NOT NULL,
  
  -- Special Requirements
  requires_id_check BOOLEAN DEFAULT FALSE,
  requires_signature BOOLEAN DEFAULT TRUE,
  delivery_instructions TEXT,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Delivery Tracking (GPS Breadcrumbs)
CREATE TABLE IF NOT EXISTS delivery_tracking (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  delivery_id UUID NOT NULL REFERENCES deliveries(id) ON DELETE CASCADE,
  driver_id UUID NOT NULL REFERENCES drivers(id),
  
  -- Location
  latitude DECIMAL(10, 8) NOT NULL,
  longitude DECIMAL(11, 8) NOT NULL,
  
  -- Status at this point
  status TEXT,
  
  -- Metadata
  speed DECIMAL(5, 2),  -- km/h
  heading DECIMAL(5, 2),  -- degrees
  
  tracked_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_delivery_tracking_delivery ON delivery_tracking(delivery_id, tracked_at DESC);

-- Delivery Proof (Immutable Evidence)
CREATE TABLE IF NOT EXISTS delivery_proof (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  delivery_id UUID NOT NULL REFERENCES deliveries(id) ON DELETE CASCADE,
  
  -- Proof Type
  proof_type proof_type NOT NULL,
  
  -- OTP
  otp_code TEXT,
  otp_verified BOOLEAN,
  
  -- Signature
  signature_data_url TEXT,  -- Base64 signature image
  
  -- ID Check
  id_number_verified TEXT,
  id_document_photo_url TEXT,
  
  -- Photo Proof
  photo_url TEXT,
  
  -- Recipient
  received_by_name TEXT NOT NULL,
  received_by_phone TEXT,
  relationship_to_patient TEXT,  -- 'patient', 'caregiver', 'other'
  
  -- Metadata
  captured_at TIMESTAMPTZ DEFAULT NOW(),
  captured_by UUID NOT NULL REFERENCES drivers(id),
  
  -- Geolocation of proof
  latitude DECIMAL(10, 8),
  longitude DECIMAL(11, 8)
);

-- ============================================================================
-- PAYMENT TABLES (Paystack Integration)
-- ============================================================================

-- Payments
CREATE TABLE IF NOT EXISTS payments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  payment_reference TEXT UNIQUE NOT NULL,
  
  -- Order
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  patient_id UUID NOT NULL REFERENCES user_profiles(id),
  
  -- Paystack
  paystack_reference TEXT UNIQUE,
  paystack_access_code TEXT,
  paystack_authorization_url TEXT,
  
  -- Amounts
  amount DECIMAL(10, 2) NOT NULL,
  paystack_fee DECIMAL(10, 2),
  net_amount DECIMAL(10, 2),
  
  -- Currency
  currency TEXT DEFAULT 'ZAR',
  
  -- Status
  status payment_status DEFAULT 'pending',
  
  -- Timestamps
  initiated_at TIMESTAMPTZ DEFAULT NOW(),
  paid_at TIMESTAMPTZ,
  failed_at TIMESTAMPTZ,
  
  -- Response
  paystack_response JSONB,
  failure_reason TEXT,
  
  -- Metadata
  payment_method TEXT,  -- 'card', 'eft', 'mobile_money'
  channel TEXT,
  ip_address INET,
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Payment Splits (Pharmacy + Delivery Fee)
CREATE TABLE IF NOT EXISTS payment_splits (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  payment_id UUID NOT NULL REFERENCES payments(id) ON DELETE CASCADE,
  
  -- Split Type
  split_type TEXT NOT NULL,  -- 'pharmacy', 'delivery', 'platform_fee'
  
  -- Recipient
  pharmacy_id UUID REFERENCES pharmacies(id),
  driver_id UUID REFERENCES drivers(id),
  
  -- Paystack Subaccount
  paystack_subaccount_code TEXT,
  
  -- Amount
  amount DECIMAL(10, 2) NOT NULL,
  percentage DECIMAL(5, 2),
  
  -- Status
  settled BOOLEAN DEFAULT FALSE,
  settled_at TIMESTAMPTZ,
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Payment Refunds
CREATE TABLE IF NOT EXISTS payment_refunds (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  payment_id UUID NOT NULL REFERENCES payments(id) ON DELETE CASCADE,
  
  -- Refund Details
  refund_amount DECIMAL(10, 2) NOT NULL,
  refund_reason TEXT NOT NULL,
  
  -- Paystack
  paystack_refund_reference TEXT UNIQUE,
  paystack_response JSONB,
  
  -- Status
  status TEXT DEFAULT 'pending',  -- 'pending', 'processing', 'completed', 'failed'
  
  -- Initiated By
  initiated_by UUID REFERENCES user_profiles(id),
  
  -- Timestamps
  initiated_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- MESSAGING SYSTEM (Restricted Communication)
-- ============================================================================

-- Message Threads
CREATE TABLE IF NOT EXISTS message_threads (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Participants
  patient_id UUID NOT NULL REFERENCES user_profiles(id),
  other_user_id UUID REFERENCES user_profiles(id),
  
  -- Context
  order_id UUID REFERENCES orders(id),
  delivery_id UUID REFERENCES deliveries(id),
  pharmacy_id UUID REFERENCES pharmacies(id),
  clinic_id UUID REFERENCES clinics(id),
  hospital_id UUID REFERENCES hospitals(id),
  
  -- Type (Determines allowed communication)
  thread_type message_type NOT NULL,
  
  -- Status
  is_active BOOLEAN DEFAULT TRUE,
  closed_at TIMESTAMPTZ,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Messages (All logged for compliance)
CREATE TABLE IF NOT EXISTS messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  thread_id UUID NOT NULL REFERENCES message_threads(id) ON DELETE CASCADE,
  
  -- Sender
  sender_id UUID NOT NULL REFERENCES user_profiles(id),
  sender_role user_role NOT NULL,
  
  -- Content (Monitored for medical advice - NOT ALLOWED)
  message_text TEXT NOT NULL,
  
  -- Attachments (e.g., delivery photo)
  attachment_url TEXT,
  attachment_type TEXT,
  
  -- Status
  is_read BOOLEAN DEFAULT FALSE,
  read_at TIMESTAMPTZ,
  
  -- Flags (Auto-moderation)
  flagged_for_review BOOLEAN DEFAULT FALSE,
  flag_reason TEXT,
  
  -- System Message
  is_system_message BOOLEAN DEFAULT FALSE,
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_messages_thread ON messages(thread_id, created_at DESC);

-- ============================================================================
-- AUDIT & COMPLIANCE TABLES (POPIA, SAPC)
-- ============================================================================

-- Audit Log (Comprehensive Activity Tracking)
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Actor
  user_id UUID REFERENCES user_profiles(id),
  user_role user_role,
  
  -- Action
  action TEXT NOT NULL,  -- 'view', 'create', 'update', 'delete', 'verify', 'dispense', 'deliver'
  resource_type TEXT NOT NULL,  -- 'prescription', 'order', 'patient_data', etc.
  resource_id UUID,
  
  -- Details
  description TEXT,
  old_values JSONB,
  new_values JSONB,
  
  -- Context
  ip_address INET,
  user_agent TEXT,
  session_id TEXT,
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_audit_logs_user ON audit_logs(user_id, created_at DESC);
CREATE INDEX idx_audit_logs_resource ON audit_logs(resource_type, resource_id, created_at DESC);

-- Consent Records (POPIA Compliance)
CREATE TABLE IF NOT EXISTS consent_records (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
  
  -- Consent Type
  consent_type TEXT NOT NULL,  -- 'data_processing', 'prescription_upload', 'marketing', 'third_party_sharing'
  
  -- Consent
  consent_given BOOLEAN NOT NULL,
  consent_text TEXT NOT NULL,  -- Exact text shown to user
  consent_version TEXT NOT NULL,
  
  -- Metadata
  ip_address INET,
  user_agent TEXT,
  
  -- Withdrawal
  withdrawn BOOLEAN DEFAULT FALSE,
  withdrawn_at TIMESTAMPTZ,
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Data Access Log (Who accessed what patient data)
CREATE TABLE IF NOT EXISTS data_access_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Accessor
  accessed_by UUID NOT NULL REFERENCES user_profiles(id),
  accessor_role user_role NOT NULL,
  
  -- Patient Data Accessed
  patient_id UUID NOT NULL REFERENCES user_profiles(id),
  
  -- What was accessed
  data_type TEXT NOT NULL,  -- 'profile', 'prescription', 'order', 'medical_history'
  resource_id UUID,
  
  -- Purpose (Required for POPIA)
  access_purpose TEXT NOT NULL,  -- 'prescription_verification', 'order_fulfillment', 'delivery'
  
  -- Metadata
  ip_address INET,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_data_access_patient ON data_access_log(patient_id, created_at DESC);
CREATE INDEX idx_data_access_accessor ON data_access_log(accessed_by, created_at DESC);

-- ============================================================================
-- ADMIN & COMPLIANCE TABLES
-- ============================================================================

-- Pharmacy Verification (Admin Approval Process)
CREATE TABLE IF NOT EXISTS pharmacy_verifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  pharmacy_id UUID NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  
  -- Documents
  sapc_certificate_url TEXT,
  business_license_url TEXT,
  tax_clearance_url TEXT,
  bank_confirmation_url TEXT,
  
  -- Verification
  verified_by UUID REFERENCES user_profiles(id),
  verification_status TEXT DEFAULT 'pending',  -- 'pending', 'approved', 'rejected'
  verification_notes TEXT,
  verified_at TIMESTAMPTZ,
  
  -- Renewal
  next_verification_date DATE,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Pharmacy Suspensions
CREATE TABLE IF NOT EXISTS pharmacy_suspensions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  pharmacy_id UUID NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
  
  -- Suspension
  suspended_by UUID NOT NULL REFERENCES user_profiles(id),
  suspension_reason TEXT NOT NULL,
  suspended_from TIMESTAMPTZ DEFAULT NOW(),
  suspended_until TIMESTAMPTZ,
  
  -- Reinstatement
  reinstated_by UUID REFERENCES user_profiles(id),
  reinstated_at TIMESTAMPTZ,
  reinstatement_notes TEXT,
  
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Driver Performance & Reviews
CREATE TABLE IF NOT EXISTS driver_reviews (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  delivery_id UUID NOT NULL REFERENCES deliveries(id) ON DELETE CASCADE,
  driver_id UUID NOT NULL REFERENCES drivers(id),
  
  -- Review
  reviewed_by UUID NOT NULL REFERENCES user_profiles(id),  -- Patient
  rating INTEGER CHECK (rating BETWEEN 1 AND 5),
  review_text TEXT,
  
  -- Categories
  professionalism_rating INTEGER CHECK (professionalism_rating BETWEEN 1 AND 5),
  timeliness_rating INTEGER CHECK (timeliness_rating BETWEEN 1 AND 5),
  care_rating INTEGER CHECK (care_rating BETWEEN 1 AND 5),
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- VIEWS (Privacy & Data Minimization)
-- ============================================================================

-- Driver View of Deliveries (NO MEDICATION DETAILS)
CREATE VIEW driver_delivery_view AS
SELECT 
  d.id AS delivery_id,
  d.driver_id,
  d.order_id,
  
  -- Pharmacy Pickup (SAFE)
  d.pharmacy_id,
  p.name AS pharmacy_name,
  d.pickup_address,
  d.pickup_latitude,
  d.pickup_longitude,
  
  -- Patient Delivery (LIMITED)
  d.contact_name,
  d.contact_phone,
  d.delivery_address,
  d.delivery_latitude,
  d.delivery_longitude,
  d.delivery_instructions,
  
  -- NO MEDICATION INFO
  -- NO DIAGNOSIS
  -- NO PRESCRIPTION DETAILS
  
  -- Times
  d.estimated_pickup_time,
  d.estimated_delivery_time,
  
  -- Requirements
  d.requires_id_check,
  d.requires_signature,
  
  -- Status
  d.current_status,
  
  -- Earnings
  d.driver_earnings,
  
  d.created_at
FROM deliveries d
JOIN pharmacies p ON d.pharmacy_id = p.id;

-- Pharmacy Dashboard View
CREATE VIEW pharmacy_order_view AS
SELECT 
  o.id AS order_id,
  o.order_number,
  o.pharmacy_id,
  
  -- Patient (Minimal for dispensing)
  o.patient_id,
  up.full_name AS patient_name,
  up.phone_number AS patient_phone,
  
  -- Prescription
  o.prescription_id,
  pr.prescription_number,
  pr.status AS prescription_status,
  
  -- Order Status
  o.status AS order_status,
  
  -- Amounts
  o.subtotal,
  o.delivery_fee,
  o.total_amount,
  o.payment_status,
  
  -- Timestamps
  o.created_at,
  o.rx_verified_at,
  o.prepared_at,
  o.picked_up_at
  
FROM orders o
JOIN user_profiles up ON o.patient_id = up.id
LEFT JOIN prescriptions pr ON o.prescription_id = pr.id;

-- Patient Order Tracking View
CREATE VIEW patient_order_tracking AS
SELECT 
  o.id AS order_id,
  o.order_number,
  o.patient_id,
  o.status,
  o.total_amount,
  o.payment_status,
  
  -- Pharmacy
  ph.name AS pharmacy_name,
  ph.phone AS pharmacy_phone,
  
  -- Delivery
  d.id AS delivery_id,
  d.driver_id,
  dri.user_id AS driver_user_id,
  dup.full_name AS driver_name,
  dup.phone_number AS driver_phone,
  d.current_status AS delivery_status,
  d.estimated_delivery_time,
  
  -- Tracking
  (SELECT jsonb_agg(jsonb_build_object(
    'latitude', dt.latitude,
    'longitude', dt.longitude,
    'tracked_at', dt.tracked_at
  ) ORDER BY dt.tracked_at DESC)
  FROM delivery_tracking dt
  WHERE dt.delivery_id = d.id
  LIMIT 20) AS recent_locations,
  
  o.created_at,
  o.delivered_at
  
FROM orders o
LEFT JOIN pharmacies ph ON o.pharmacy_id = ph.id
LEFT JOIN deliveries d ON o.id = d.order_id
LEFT JOIN drivers dri ON d.driver_id = dri.id
LEFT JOIN user_profiles dup ON dri.user_id = dup.id;

-- ============================================================================
-- FUNCTIONS (Business Logic & State Machine)
-- ============================================================================

-- Function: Validate Order Status Transition (STATE MACHINE)
CREATE OR REPLACE FUNCTION validate_order_status_transition()
RETURNS TRIGGER AS $$
DECLARE
  allowed BOOLEAN := FALSE;
BEGIN
  -- Define allowed transitions
  IF (OLD.status = 'created' AND NEW.status IN ('rx_uploaded', 'cancelled')) THEN allowed := TRUE;
  ELSIF (OLD.status = 'rx_uploaded' AND NEW.status IN ('rx_verified', 'rx_rejected', 'cancelled')) THEN allowed := TRUE;
  ELSIF (OLD.status = 'rx_verified' AND NEW.status IN ('prepared', 'cancelled')) THEN allowed := TRUE;
  ELSIF (OLD.status = 'prepared' AND NEW.status IN ('driver_assigned', 'cancelled')) THEN allowed := TRUE;
  ELSIF (OLD.status = 'driver_assigned' AND NEW.status IN ('picked_up', 'cancelled')) THEN allowed := TRUE;
  ELSIF (OLD.status = 'picked_up' AND NEW.status IN ('out_for_delivery', 'cancelled')) THEN allowed := TRUE;
  ELSIF (OLD.status = 'out_for_delivery' AND NEW.status IN ('delivered', 'cancelled')) THEN allowed := TRUE;
  ELSIF (OLD.status = 'delivered' AND NEW.status = 'closed') THEN allowed := TRUE;
  ELSIF (OLD.status = 'rx_rejected' AND NEW.status = 'cancelled') THEN allowed := TRUE;
  END IF;
  
  -- Allow if same status (no change)
  IF OLD.status = NEW.status THEN allowed := TRUE; END IF;
  
  IF NOT allowed THEN
    RAISE EXCEPTION 'Invalid order status transition from % to %', OLD.status, NEW.status;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function: Log Order Status Change
CREATE OR REPLACE FUNCTION log_order_status_change()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    INSERT INTO order_status_history (
      order_id,
      from_status,
      to_status,
      changed_by,
      system_generated
    ) VALUES (
      NEW.id,
      OLD.status,
      NEW.status,
      auth.uid(),  -- Current user from Supabase Auth
      FALSE
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function: Update Order Timestamps Based on Status
CREATE OR REPLACE FUNCTION update_order_timestamps()
RETURNS TRIGGER AS $$
BEGIN
  -- Update specific timestamp fields based on status change
  IF NEW.status = 'rx_uploaded' AND OLD.status != 'rx_uploaded' THEN
    NEW.rx_uploaded_at := NOW();
  ELSIF NEW.status = 'rx_verified' AND OLD.status != 'rx_verified' THEN
    NEW.rx_verified_at := NOW();
  ELSIF NEW.status = 'prepared' AND OLD.status != 'prepared' THEN
    NEW.prepared_at := NOW();
  ELSIF NEW.status = 'driver_assigned' AND OLD.status != 'driver_assigned' THEN
    NEW.driver_assigned_at := NOW();
  ELSIF NEW.status = 'picked_up' AND OLD.status != 'picked_up' THEN
    NEW.picked_up_at := NOW();
  ELSIF NEW.status = 'delivered' AND OLD.status != 'delivered' THEN
    NEW.delivered_at := NOW();
  ELSIF NEW.status IN ('closed', 'cancelled') AND OLD.status NOT IN ('closed', 'cancelled') THEN
    NEW.closed_at := NOW();
  END IF;
  
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function: Create Chronic Order (Auto-generation)
CREATE OR REPLACE FUNCTION create_chronic_order(enrollment_id UUID)
RETURNS UUID AS $$
DECLARE
  enrollment chronic_enrollments;
  new_order_id UUID;
  new_order_number TEXT;
BEGIN
  -- Get enrollment details
  SELECT * INTO enrollment FROM chronic_enrollments WHERE id = enrollment_id AND is_active = TRUE;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Chronic enrollment not found or inactive';
  END IF;
  
  IF enrollment.status != 'active' THEN
    RAISE EXCEPTION 'Chronic enrollment is not active';
  END IF;
  
  -- Generate order number
  new_order_number := 'CHR-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || SUBSTRING(gen_random_uuid()::TEXT, 1, 8);
  
  -- Create order
  INSERT INTO orders (
    order_number,
    patient_id,
    ordered_by,
    pharmacy_id,
    chronic_enrollment_id,
    is_chronic_order,
    prescription_id,
    delivery_address,
    delivery_latitude,
    delivery_longitude,
    delivery_contact_name,
    delivery_contact_phone,
    status
  )
  SELECT 
    new_order_number,
    enrollment.patient_id,
    enrollment.patient_id,
    enrollment.enrolled_by_pharmacy,
    enrollment.id,
    TRUE,
    enrollment.prescription_id,
    COALESCE(enrollment.delivery_address, up.street_address),
    COALESCE(enrollment.delivery_latitude, up.latitude),
    COALESCE(enrollment.delivery_longitude, up.longitude),
    up.full_name,
    up.phone_number,
    'created'
  FROM user_profiles up
  WHERE up.id = enrollment.patient_id
  RETURNING id INTO new_order_id;
  
  -- Add order item
  INSERT INTO order_items (
    order_id,
    medication_id,
    medication_name,
    medication_type,
    quantity,
    unit_price,
    total_price
  )
  SELECT 
    new_order_id,
    enrollment.medication_id,
    enrollment.medication_name,
    'chronic',
    enrollment.monthly_quantity,
    COALESCE(m.indicative_price, 0),
    COALESCE(m.indicative_price, 0) * enrollment.monthly_quantity
  FROM medications m
  WHERE m.id = enrollment.medication_id;
  
  -- Update next delivery date
  UPDATE chronic_enrollments
  SET next_delivery_date = next_delivery_date + INTERVAL '1 month'
  WHERE id = enrollment_id;
  
  RETURN new_order_id;
END;
$$ LANGUAGE plpgsql;

-- Function: Calculate Distance (Haversine)
CREATE OR REPLACE FUNCTION calculate_distance(
  lat1 DECIMAL,
  lon1 DECIMAL,
  lat2 DECIMAL,
  lon2 DECIMAL
)
RETURNS DECIMAL AS $$
DECLARE
  R DECIMAL := 6371; -- Earth radius in km
  dLat DECIMAL;
  dLon DECIMAL;
  a DECIMAL;
  c DECIMAL;
  distance DECIMAL;
BEGIN
  dLat := RADIANS(lat2 - lat1);
  dLon := RADIANS(lon2 - lon1);
  
  a := SIN(dLat/2) * SIN(dLat/2) +
       COS(RADIANS(lat1)) * COS(RADIANS(lat2)) *
       SIN(dLon/2) * SIN(dLon/2);
  
  c := 2 * ATAN2(SQRT(a), SQRT(1-a));
  distance := R * c;
  
  RETURN ROUND(distance::NUMERIC, 2);
END;
$$ LANGUAGE plpgsql;

-- Function: Calculate Delivery Fee (Distance-based)
CREATE OR REPLACE FUNCTION calculate_delivery_fee(distance_km DECIMAL)
RETURNS DECIMAL AS $$
DECLARE
  base_fee DECIMAL := 30.00; -- ZAR
  per_km_rate DECIMAL := 8.00; -- ZAR per km
  fee DECIMAL;
BEGIN
  IF distance_km <= 5 THEN
    fee := base_fee;
  ELSE
    fee := base_fee + ((distance_km - 5) * per_km_rate);
  END IF;
  
  RETURN ROUND(fee::NUMERIC, 2);
END;
$$ LANGUAGE plpgsql;

-- Function: Auto-update delivery distance and fee
CREATE OR REPLACE FUNCTION update_delivery_calculations()
RETURNS TRIGGER AS $$
DECLARE
  distance DECIMAL;
  fee DECIMAL;
BEGIN
  -- Calculate distance
  distance := calculate_distance(
    NEW.pickup_latitude,
    NEW.pickup_longitude,
    NEW.delivery_latitude,
    NEW.delivery_longitude
  );
  
  -- Calculate fee
  fee := calculate_delivery_fee(distance);
  
  NEW.distance_km := distance;
  NEW.delivery_fee := fee;
  NEW.driver_earnings := fee * 0.75; -- Driver gets 75%
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function: Update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Drop existing triggers if they exist
DROP TRIGGER IF EXISTS enforce_order_status_transition ON orders;
DROP TRIGGER IF EXISTS log_order_status ON orders;
DROP TRIGGER IF EXISTS update_order_times ON orders;
DROP TRIGGER IF EXISTS calculate_delivery_details ON deliveries;
DROP TRIGGER IF EXISTS update_user_profiles_updated_at ON user_profiles;
DROP TRIGGER IF EXISTS update_pharmacies_updated_at ON pharmacies;
DROP TRIGGER IF EXISTS update_orders_updated_at ON orders;
DROP TRIGGER IF EXISTS update_deliveries_updated_at ON deliveries;

-- Order Status Validation
CREATE TRIGGER enforce_order_status_transition
  BEFORE UPDATE ON orders
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION validate_order_status_transition();

-- Order Status History Logging
CREATE TRIGGER log_order_status
  AFTER UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION log_order_status_change();

-- Order Timestamp Updates
CREATE TRIGGER update_order_times
  BEFORE UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION update_order_timestamps();

-- Delivery Calculations
CREATE TRIGGER calculate_delivery_details
  BEFORE INSERT OR UPDATE ON deliveries
  FOR EACH ROW
  EXECUTE FUNCTION update_delivery_calculations();

-- Updated_at Triggers
CREATE TRIGGER update_user_profiles_updated_at
  BEFORE UPDATE ON user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_pharmacies_updated_at
  BEFORE UPDATE ON pharmacies
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_orders_updated_at
  BEFORE UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_deliveries_updated_at
  BEFORE UPDATE ON deliveries
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- INDEXES (Performance Optimization)
-- ============================================================================

-- User & Role Indexes
CREATE INDEX IF NOT EXISTS idx_user_profiles_phone ON user_profiles(phone_number);
CREATE INDEX IF NOT EXISTS idx_user_profiles_email ON user_profiles(email);
CREATE INDEX IF NOT EXISTS idx_user_profiles_id_number ON user_profiles(id_number);
CREATE INDEX IF NOT EXISTS idx_user_role_assignments_user ON user_role_assignments(user_id, role);
CREATE INDEX IF NOT EXISTS idx_caregivers_patient ON caregivers(patient_id);

-- Organization Indexes
CREATE INDEX IF NOT EXISTS idx_pharmacies_sapc ON pharmacies(sapc_number);
CREATE INDEX IF NOT EXISTS idx_pharmacies_active ON pharmacies(is_active, is_verified);

-- Prescription Indexes
CREATE INDEX IF NOT EXISTS idx_prescriptions_patient ON prescriptions(patient_id, status);
CREATE INDEX IF NOT EXISTS idx_prescriptions_uploaded_by ON prescriptions(uploaded_by);
CREATE INDEX IF NOT EXISTS idx_prescriptions_number ON prescriptions(prescription_number);
CREATE INDEX IF NOT EXISTS idx_prescriptions_status ON prescriptions(status);
CREATE INDEX IF NOT EXISTS idx_prescriptions_can_use ON prescriptions(can_be_used_for_orders) WHERE can_be_used_for_orders = TRUE;
CREATE INDEX IF NOT EXISTS idx_prescription_items_prescription ON prescription_items(prescription_id);

-- Chronic Enrollments
CREATE INDEX IF NOT EXISTS idx_chronic_enrollments_patient ON chronic_enrollments(patient_id, status);
CREATE INDEX IF NOT EXISTS idx_chronic_enrollments_next_delivery ON chronic_enrollments(next_delivery_date) WHERE status = 'active';

-- Order Indexes
CREATE INDEX IF NOT EXISTS idx_orders_patient ON orders(patient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_pharmacy ON orders(pharmacy_id, status);
CREATE INDEX IF NOT EXISTS idx_orders_prescription ON orders(prescription_id);
CREATE INDEX IF NOT EXISTS idx_orders_number ON orders(order_number);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items(order_id);

-- Delivery Indexes
CREATE INDEX IF NOT EXISTS idx_deliveries_driver ON deliveries(driver_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_deliveries_order ON deliveries(order_id);
CREATE INDEX IF NOT EXISTS idx_drivers_available ON drivers(is_available, is_active);
CREATE INDEX IF NOT EXISTS idx_delivery_tracking_delivery ON delivery_tracking(delivery_id, tracked_at DESC);

-- Payment Indexes
CREATE INDEX IF NOT EXISTS idx_payments_order ON payments(order_id);
CREATE INDEX IF NOT EXISTS idx_payments_patient ON payments(patient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payments_reference ON payments(payment_reference);
CREATE INDEX IF NOT EXISTS idx_payments_paystack_ref ON payments(paystack_reference);

-- Message Indexes
CREATE INDEX IF NOT EXISTS idx_message_threads_patient ON message_threads(patient_id, is_active);
CREATE INDEX IF NOT EXISTS idx_message_threads_order ON message_threads(order_id);
CREATE INDEX IF NOT EXISTS idx_messages_thread ON messages(thread_id, created_at DESC);

-- Audit Indexes
CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON audit_logs(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_resource ON audit_logs(resource_type, resource_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_data_access_patient ON data_access_log(patient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_data_access_accessor ON data_access_log(accessed_by, created_at DESC);

-- ============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_role_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE caregivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE pharmacies ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinics ENABLE ROW LEVEL SECURITY;
ALTER TABLE hospitals ENABLE ROW LEVEL SECURITY;
ALTER TABLE medications ENABLE ROW LEVEL SECURITY;
ALTER TABLE prescriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE prescription_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE chronic_enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE drivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE deliveries ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_tracking ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_proof ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_splits ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_refunds ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_threads ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE consent_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE data_access_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE pharmacy_verifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_reviews ENABLE ROW LEVEL SECURITY;

-- Helper Function: Check if user has role
CREATE OR REPLACE FUNCTION has_role(check_role user_role)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM user_role_assignments
    WHERE user_id = auth.uid()
    AND role = check_role
    AND is_active = TRUE
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper Function: Check if user has role at organization
CREATE OR REPLACE FUNCTION has_role_at_org(check_role user_role, org_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM user_role_assignments
    WHERE user_id = auth.uid()
    AND role = check_role
    AND organization_id = org_id
    AND is_active = TRUE
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper Function: Get pharmacist's pharmacy IDs (SECURITY DEFINER to avoid recursion)
CREATE OR REPLACE FUNCTION get_pharmacist_pharmacy_ids()
RETURNS TABLE(pharmacy_id UUID) AS $$
BEGIN
  RETURN QUERY
  SELECT organization_id
  FROM user_role_assignments
  WHERE user_id = auth.uid()
  AND role = 'pharmacist'
  AND is_active = TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Helper Function: Check if prescription belongs to pharmacist's orders (SECURITY DEFINER)
CREATE OR REPLACE FUNCTION pharmacist_can_access_prescription(prescription_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM orders
    WHERE prescription_id = prescription_uuid
    AND pharmacy_id IN (SELECT pharmacy_id FROM get_pharmacist_pharmacy_ids())
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- ============================================================================
-- RLS POLICIES: USER PROFILES
-- ============================================================================

-- Drop existing policies if they exist
DROP POLICY IF EXISTS user_profiles_select_own ON user_profiles;
DROP POLICY IF EXISTS user_profiles_update_own ON user_profiles;
DROP POLICY IF EXISTS user_profiles_select_admin ON user_profiles;
DROP POLICY IF EXISTS user_profiles_select_pharmacist ON user_profiles;

-- Users can view their own profile
CREATE POLICY user_profiles_select_own
  ON user_profiles FOR SELECT
  USING (id = auth.uid());

-- Users can update their own profile
CREATE POLICY user_profiles_update_own
  ON user_profiles FOR UPDATE
  USING (id = auth.uid());

-- Admins can view all profiles
CREATE POLICY user_profiles_select_admin
  ON user_profiles FOR SELECT
  USING (has_role('admin'));

-- Pharmacists can view patient profiles for their orders
CREATE POLICY user_profiles_select_pharmacist
  ON user_profiles FOR SELECT
  USING (
    has_role('pharmacist') AND
    id IN (
      SELECT patient_id FROM orders o
      JOIN user_role_assignments ura ON ura.user_id = auth.uid()
      WHERE ura.role = 'pharmacist'
      AND o.pharmacy_id = ura.organization_id
    )
  );

-- ============================================================================
-- RLS POLICIES: ORDERS
-- ============================================================================

-- Patients can view their own orders
CREATE POLICY orders_select_patient
  ON orders FOR SELECT
  USING (patient_id = auth.uid() OR ordered_by = auth.uid());

-- Patients can create orders
CREATE POLICY orders_insert_patient
  ON orders FOR INSERT
  WITH CHECK (patient_id = auth.uid() OR ordered_by = auth.uid());

-- Patients can update their own orders (limited)
CREATE POLICY orders_update_patient
  ON orders FOR UPDATE
  USING (patient_id = auth.uid() AND status IN ('created', 'rx_uploaded'));

-- Caregivers can view and manage orders for their patients
CREATE POLICY orders_select_caregiver
  ON orders FOR SELECT
  USING (
    patient_id IN (
      SELECT patient_id FROM caregivers
      WHERE caregiver_id = auth.uid() AND is_active = TRUE
    )
  );

-- Pharmacists can view orders for their pharmacy
CREATE POLICY orders_select_pharmacist
  ON orders FOR SELECT
  USING (
    has_role('pharmacist') AND
    pharmacy_id IN (SELECT pharmacy_id FROM get_pharmacist_pharmacy_ids())
  );

-- Pharmacists can update orders at their pharmacy
CREATE POLICY orders_update_pharmacist
  ON orders FOR UPDATE
  USING (
    has_role('pharmacist') AND
    pharmacy_id IN (SELECT pharmacy_id FROM get_pharmacist_pharmacy_ids())
  );

-- Drivers can view assigned orders (through deliveries)
CREATE POLICY orders_select_driver
  ON orders FOR SELECT
  USING (
    has_role('driver') AND
    id IN (
      SELECT order_id FROM deliveries d
      JOIN drivers dr ON d.driver_id = dr.id
      WHERE dr.user_id = auth.uid()
    )
  );

-- Admins can view all orders
CREATE POLICY orders_select_admin
  ON orders FOR SELECT
  USING (has_role('admin'));

-- ============================================================================
-- RLS POLICIES: PRESCRIPTIONS
-- ============================================================================

-- Patients can view their own prescriptions (both uploaded by them AND for them)
CREATE POLICY prescriptions_select_patient
  ON prescriptions FOR SELECT
  USING (patient_id = auth.uid() OR uploaded_by = auth.uid());

-- Patients can create/upload prescriptions for themselves
CREATE POLICY prescriptions_insert_patient
  ON prescriptions FOR INSERT
  WITH CHECK (patient_id = auth.uid() AND uploaded_by = auth.uid());

-- Patients can update their own uploaded prescriptions (only if not yet verified)
CREATE POLICY prescriptions_update_patient
  ON prescriptions FOR UPDATE
  USING (
    uploaded_by = auth.uid() 
    AND status = 'pending_verification' 
    AND is_locked = FALSE
  );

-- Pharmacists can view prescriptions for verification (linked to orders at their pharmacy)
CREATE POLICY prescriptions_select_pharmacist
  ON prescriptions FOR SELECT
  USING (
    has_role('pharmacist') AND
    pharmacist_can_access_prescription(id)
  );

-- Pharmacists can update prescriptions (verify/reject) at their pharmacy
CREATE POLICY prescriptions_update_pharmacist
  ON prescriptions FOR UPDATE
  USING (
    has_role('pharmacist') AND
    pharmacist_can_access_prescription(id)
  );

-- Clinicians can view prescriptions they issued OR uploaded
CREATE POLICY prescriptions_select_clinician
  ON prescriptions FOR SELECT
  USING (issued_by = auth.uid() OR uploaded_by = auth.uid());

-- Clinicians can create/upload prescriptions (for their patients)
CREATE POLICY prescriptions_insert_clinician
  ON prescriptions FOR INSERT
  WITH CHECK (
    has_role('clinician') AND 
    (uploaded_by = auth.uid() OR issued_by = auth.uid())
  );

-- Clinicians can update prescriptions they uploaded (only if not verified)
CREATE POLICY prescriptions_update_clinician
  ON prescriptions FOR UPDATE
  USING (
    has_role('clinician') 
    AND uploaded_by = auth.uid() 
    AND status = 'pending_verification'
    AND is_locked = FALSE
  );

-- Admins can view all prescriptions
CREATE POLICY prescriptions_select_admin
  ON prescriptions FOR SELECT
  USING (has_role('admin'));

-- Admins can manage all prescriptions
CREATE POLICY prescriptions_all_admin
  ON prescriptions FOR ALL
  USING (has_role('admin'));

-- ============================================================================
-- RLS POLICIES: DELIVERIES
-- ============================================================================

-- Patients can view their deliveries
CREATE POLICY deliveries_select_patient
  ON deliveries FOR SELECT
  USING (
    order_id IN (
      SELECT id FROM orders WHERE patient_id = auth.uid()
    )
  );

-- Drivers can view their assigned deliveries
CREATE POLICY deliveries_select_driver
  ON deliveries FOR SELECT
  USING (
    driver_id IN (
      SELECT id FROM drivers WHERE user_id = auth.uid()
    )
  );

-- Drivers can update their deliveries
CREATE POLICY deliveries_update_driver
  ON deliveries FOR UPDATE
  USING (
    driver_id IN (
      SELECT id FROM drivers WHERE user_id = auth.uid()
    )
  );

-- Pharmacists can view deliveries from their pharmacy
CREATE POLICY deliveries_select_pharmacist
  ON deliveries FOR SELECT
  USING (
    pharmacy_id IN (SELECT pharmacy_id FROM get_pharmacist_pharmacy_ids())
  );

-- Admins can view all deliveries
CREATE POLICY deliveries_select_admin
  ON deliveries FOR SELECT
  USING (has_role('admin'));

-- ============================================================================
-- RLS POLICIES: PAYMENTS
-- ============================================================================

-- Patients can view their own payments
CREATE POLICY payments_select_patient
  ON payments FOR SELECT
  USING (patient_id = auth.uid());

-- Patients can create payments
CREATE POLICY payments_insert_patient
  ON payments FOR INSERT
  WITH CHECK (patient_id = auth.uid());

-- Pharmacies can view payments for their orders
CREATE POLICY payments_select_pharmacy
  ON payments FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = payments.order_id
      AND orders.pharmacy_id IN (SELECT pharmacy_id FROM get_pharmacist_pharmacy_ids())
    )
  );

-- Admins can view all payments
CREATE POLICY payments_select_admin
  ON payments FOR SELECT
  USING (has_role('admin'));

-- ============================================================================
-- RLS POLICIES: MESSAGES
-- ============================================================================

-- Users can view messages in their threads
CREATE POLICY messages_select_participant
  ON messages FOR SELECT
  USING (
    thread_id IN (
      SELECT id FROM message_threads
      WHERE patient_id = auth.uid()
      OR other_user_id = auth.uid()
    )
  );

-- Users can send messages in their threads
CREATE POLICY messages_insert_participant
  ON messages FOR INSERT
  WITH CHECK (
    sender_id = auth.uid() AND
    thread_id IN (
      SELECT id FROM message_threads
      WHERE patient_id = auth.uid()
      OR other_user_id = auth.uid()
    )
  );

-- Admins can view all messages (compliance monitoring)
CREATE POLICY messages_select_admin
  ON messages FOR SELECT
  USING (has_role('admin'));

-- ============================================================================
-- RLS POLICIES: AUDIT LOGS
-- ============================================================================

-- Users can view their own audit logs
CREATE POLICY audit_logs_select_own
  ON audit_logs FOR SELECT
  USING (user_id = auth.uid());

-- Admins can view all audit logs
CREATE POLICY audit_logs_select_admin
  ON audit_logs FOR SELECT
  USING (has_role('admin'));

-- System can insert audit logs (all users)
CREATE POLICY audit_logs_insert_all
  ON audit_logs FOR INSERT
  WITH CHECK (true);

-- ============================================================================
-- RLS POLICIES: MEDICATIONS (Public Catalog)
-- ============================================================================

-- Everyone can view active medications
CREATE POLICY medications_select_all
  ON medications FOR SELECT
  USING (is_active = TRUE);

-- Admins can manage medications
CREATE POLICY medications_all_admin
  ON medications FOR ALL
  USING (has_role('admin'));

-- ============================================================================
-- RLS POLICIES: PHARMACIES (Public Directory)
-- ============================================================================

-- Everyone can view verified, active pharmacies
CREATE POLICY pharmacies_select_public
  ON pharmacies FOR SELECT
  USING (is_active = TRUE AND is_verified = TRUE);

-- Pharmacy managers can update their pharmacy
CREATE POLICY pharmacies_update_manager
  ON pharmacies FOR UPDATE
  USING (
    has_role_at_org('pharmacy_manager', id) OR
    has_role_at_org('pharmacist', id)
  );

-- Admins can manage all pharmacies
CREATE POLICY pharmacies_all_admin
  ON pharmacies FOR ALL
  USING (has_role('admin'));

-- ============================================================================
-- SAMPLE DATA (Optional - for testing)
-- ============================================================================

-- Insert sample medications
INSERT INTO medications (name, generic_name, medication_type, nappi_code, requires_prescription, is_chronic_eligible, indicative_price) VALUES
('Panado 500mg Tablets', 'Paracetamol', 'otc', '123456', FALSE, FALSE, 45.00),
('Disprin Tablets', 'Aspirin', 'otc', '234567', FALSE, FALSE, 38.50),
('Allergex 5mg Tablets', 'Chlorphenamine', 'otc', '345678', FALSE, FALSE, 52.00),
('Eltroxin 100mcg', 'Levothyroxine', 'prescription', '456789', TRUE, TRUE, 125.00),
('Glucophage 500mg', 'Metformin', 'prescription', '567890', TRUE, TRUE, 180.00),
('Atorvastatin 20mg', 'Atorvastatin', 'prescription', '678901', TRUE, TRUE, 220.00);

-- ============================================================================
-- COMMENTS & DOCUMENTATION
-- ============================================================================

COMMENT ON TABLE user_profiles IS 'Extended user profile information (POPIA protected)';
COMMENT ON TABLE pharmacies IS 'Licensed pharmacies (SAPC registered - only entities that can dispense)';
COMMENT ON TABLE prescriptions IS 'Digital prescriptions (must be verified by pharmacist before dispensing)';
COMMENT ON TABLE orders IS 'Medication orders (strict state machine - no skipping steps)';
COMMENT ON TABLE deliveries IS 'Delivery assignments (drivers see NO medication details)';
COMMENT ON TABLE messages IS 'Platform messaging (NO medical advice allowed)';
COMMENT ON TABLE audit_logs IS 'Comprehensive audit trail for regulatory compliance';
COMMENT ON TABLE consent_records IS 'POPIA consent tracking';
COMMENT ON TABLE delivery_proof IS 'Immutable delivery evidence (OTP, signature, ID)';

COMMENT ON COLUMN orders.status IS 'Order status - follows strict state machine (no rollback)';
COMMENT ON COLUMN prescriptions.is_locked IS 'Locked after pharmacist verification - immutable';
COMMENT ON COLUMN deliveries.contact_name IS 'Driver sees contact name - NOT medication details';
COMMENT ON COLUMN messages.flagged_for_review IS 'Auto-flagged if medical advice detected';

-- ============================================================================
-- END OF SCHEMA
-- ============================================================================

-- Success message
DO $$
BEGIN
  RAISE NOTICE '✅ Nrome Medication Delivery Platform Schema created successfully!';
  RAISE NOTICE '📋 Total Tables: 35+';
  RAISE NOTICE '🔒 RLS Policies: Enabled on all tables';
  RAISE NOTICE '⚙️ Functions: State machine, chronic automation, distance calculation';
  RAISE NOTICE '🇿🇦 Compliance: SAPC, POPIA ready';
  RAISE NOTICE '';
  RAISE NOTICE '🚀 Next Steps:';
  RAISE NOTICE '1. Configure Supabase Storage buckets for prescription uploads';
  RAISE NOTICE '2. Set up Paystack webhook endpoint';
  RAISE NOTICE '3. Configure SendGrid/Twilio for notifications';
  RAISE NOTICE '4. Deploy edge functions for chronic order automation';
  RAISE NOTICE '5. Test state machine transitions thoroughly';
END $$;
