-- ============================================================================
-- FIX RLS INFINITE RECURSION - Apply This Migration
-- ============================================================================
-- This fixes the infinite recursion error by adding SECURITY DEFINER helper
-- functions that break the circular policy references
-- ============================================================================

-- Drop existing problematic policies
DROP POLICY IF EXISTS prescriptions_select_pharmacist ON prescriptions;
DROP POLICY IF EXISTS prescriptions_update_pharmacist ON prescriptions;
DROP POLICY IF EXISTS orders_select_pharmacist ON orders;
DROP POLICY IF EXISTS orders_update_pharmacist ON orders;
DROP POLICY IF EXISTS deliveries_select_pharmacist ON deliveries;
DROP POLICY IF EXISTS payments_select_pharmacy ON payments;

-- Create SECURITY DEFINER helper functions (bypass RLS internally)
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

-- Recreate policies using SECURITY DEFINER functions (no recursion)

-- PRESCRIPTIONS: Pharmacists can view/update prescriptions for their orders
CREATE POLICY prescriptions_select_pharmacist
  ON prescriptions FOR SELECT
  USING (
    has_role('pharmacist') AND
    pharmacist_can_access_prescription(id)
  );

CREATE POLICY prescriptions_update_pharmacist
  ON prescriptions FOR UPDATE
  USING (
    has_role('pharmacist') AND
    pharmacist_can_access_prescription(id)
  );

-- ORDERS: Pharmacists can view/update orders at their pharmacy
CREATE POLICY orders_select_pharmacist
  ON orders FOR SELECT
  USING (
    has_role('pharmacist') AND
    pharmacy_id IN (SELECT pharmacy_id FROM get_pharmacist_pharmacy_ids())
  );

CREATE POLICY orders_update_pharmacist
  ON orders FOR UPDATE
  USING (
    has_role('pharmacist') AND
    pharmacy_id IN (SELECT pharmacy_id FROM get_pharmacist_pharmacy_ids())
  );

-- DELIVERIES: Pharmacists can view deliveries from their pharmacy
CREATE POLICY deliveries_select_pharmacist
  ON deliveries FOR SELECT
  USING (
    pharmacy_id IN (SELECT pharmacy_id FROM get_pharmacist_pharmacy_ids())
  );

-- PAYMENTS: Pharmacies can view payments for their orders
CREATE POLICY payments_select_pharmacy
  ON payments FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM orders
      WHERE orders.id = payments.order_id
      AND orders.pharmacy_id IN (SELECT pharmacy_id FROM get_pharmacist_pharmacy_ids())
    )
  );

-- Success message
DO $$
BEGIN
  RAISE NOTICE '✅ RLS policies fixed - infinite recursion resolved!';
  RAISE NOTICE '🔧 SECURITY DEFINER functions added to break circular references';
  RAISE NOTICE '📋 Updated policies: prescriptions, orders, deliveries, payments';
END $$;
