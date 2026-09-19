-- ==================================================
-- VERIFICATION BADGE & DISPLAY COMPONENTS
-- ==================================================
-- Phase 9: Display verification badges on practitioner profiles

-- ==================================================
-- CREATE VIEW FOR PUBLIC PRACTITIONER DIRECTORY
-- ==================================================

CREATE OR REPLACE VIEW public_practitioners AS
SELECT 
    p.id,
    p.full_name,
    p.profession,
    p.specialty,
    p.practice_name,
    p.medical_scheme_billing_supported,
    p.verification_status,
    p.verified_at,
    p.trust_score,
    -- Hide exact address, show only general area
    SUBSTRING(p.address FROM 1 FOR POSITION(',' IN p.address) - 1) as general_area,
    -- Calculate distance from patient location (requires lat/lng from patient)
    p.latitude,
    p.longitude,
    -- Verification badge info
    CASE 
        WHEN p.verification_status = 'verified' 
             AND p.verification_expires_at > NOW() 
        THEN true 
        ELSE false 
    END as is_verified,
    p.verification_expires_at
FROM practitioners p
WHERE p.verification_status = 'verified'
AND p.verification_expires_at > NOW()
ORDER BY p.trust_score DESC, p.verified_at DESC;

COMMENT ON VIEW public_practitioners IS 'Public directory of verified practitioners with limited information';

-- Grant public read access
GRANT SELECT ON public_practitioners TO anon;
GRANT SELECT ON public_practitioners TO authenticated;

-- ==================================================
-- HELPER FUNCTIONS FOR DISPLAY
-- ==================================================

-- Function to get verification badge HTML
CREATE OR REPLACE FUNCTION get_verification_badge(p_practitioner_id UUID)
RETURNS TEXT AS $$
DECLARE
    v_practitioner practitioners;
    v_badge TEXT;
BEGIN
    SELECT * INTO v_practitioner FROM practitioners WHERE id = p_practitioner_id;
    
    IF v_practitioner.verification_status = 'verified' 
       AND v_practitioner.verification_expires_at > NOW() THEN
        v_badge := '<span class="badge bg-success">
            <i class="fas fa-check-circle me-1"></i>Verified Practitioner
        </span>
        <div class="verification-details">
            <small class="text-muted">
                Verified on ' || TO_CHAR(v_practitioner.verified_at, 'DD Month YYYY') || '
            </small>
        </div>';
    ELSE
        v_badge := '<span class="badge bg-secondary">Not Verified</span>';
    END IF;
    
    RETURN v_badge;
END;
$$ LANGUAGE plpgsql;

-- Function to check if practitioner is verified
CREATE OR REPLACE FUNCTION is_practitioner_verified(p_practitioner_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_practitioner practitioners;
BEGIN
    SELECT * INTO v_practitioner FROM practitioners WHERE id = p_practitioner_id;
    
    RETURN (
        v_practitioner.verification_status = 'verified' 
        AND v_practitioner.verification_expires_at > NOW()
    );
END;
$$ LANGUAGE plpgsql;

-- Function to get practitioner profile with verification info
CREATE OR REPLACE FUNCTION get_practitioner_profile_for_patient(p_practitioner_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_profile JSONB;
BEGIN
    SELECT jsonb_build_object(
        'id', p.id,
        'full_name', p.full_name,
        'profession', p.profession,
        'specialty', p.specialty,
        'practice_name', p.practice_name,
        'registration_number', p.registration_number,
        'medical_scheme_billing', p.medical_scheme_billing_supported,
        'verification', jsonb_build_object(
            'is_verified', CASE 
                WHEN p.verification_status = 'verified' AND p.verification_expires_at > NOW() 
                THEN true 
                ELSE false 
            END,
            'verified_at', p.verified_at,
            'verification_expires_at', p.verification_expires_at,
            'trust_score', p.trust_score
        ),
        'general_area', SUBSTRING(p.address FROM 1 FOR POSITION(',' IN p.address) - 1)
    ) INTO v_profile
    FROM practitioners p
    WHERE p.id = p_practitioner_id
    AND p.verification_status = 'verified';
    
    RETURN v_profile;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================================================
-- SEARCH FUNCTION FOR VERIFIED PRACTITIONERS
-- ==================================================

CREATE OR REPLACE FUNCTION search_verified_practitioners(
    p_search_term TEXT DEFAULT NULL,
    p_profession TEXT DEFAULT NULL,
    p_specialty TEXT DEFAULT NULL,
    p_medical_scheme_billing BOOLEAN DEFAULT NULL,
    p_patient_lat DECIMAL DEFAULT NULL,
    p_patient_lng DECIMAL DEFAULT NULL,
    p_max_distance_km INTEGER DEFAULT 50
)
RETURNS TABLE (
    practitioner_id UUID,
    full_name TEXT,
    profession TEXT,
    specialty TEXT,
    practice_name TEXT,
    general_area TEXT,
    is_verified BOOLEAN,
    trust_score INTEGER,
    distance_km DECIMAL,
    registration_number TEXT,
    medical_scheme_billing BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id as practitioner_id,
        p.full_name,
        p.profession,
        p.specialty,
        p.practice_name,
        SUBSTRING(p.address FROM 1 FOR POSITION(',' IN p.address) - 1) as general_area,
        true as is_verified,
        p.trust_score,
        -- Calculate distance (simplified Haversine formula)
        CASE 
            WHEN p_patient_lat IS NOT NULL AND p_patient_lng IS NOT NULL THEN
                ROUND(
                    6371 * acos(
                        cos(radians(p_patient_lat)) * cos(radians(p.latitude)) * 
                        cos(radians(p.longitude) - radians(p_patient_lng)) + 
                        sin(radians(p_patient_lat)) * sin(radians(p.latitude))
                    )::NUMERIC,
                    2
                )
            ELSE NULL
        END as distance_km,
        p.registration_number,
        p.medical_scheme_billing_supported as medical_scheme_billing
    FROM practitioners p
    WHERE 
        -- Must be verified and not expired
        p.verification_status = 'verified'
        AND p.verification_expires_at > NOW()
        -- Optional search filters
        AND (p_search_term IS NULL OR 
             p.full_name ILIKE '%' || p_search_term || '%' OR
             p.practice_name ILIKE '%' || p_search_term || '%' OR
             p.specialty ILIKE '%' || p_search_term || '%')
        AND (p_profession IS NULL OR p.profession = p_profession)
        AND (p_specialty IS NULL OR p.specialty = p_specialty)
        AND (p_medical_scheme_billing IS NULL OR p.medical_scheme_billing_supported = p_medical_scheme_billing)
    ORDER BY 
        -- Prioritize by distance (if coordinates provided), then trust score
        CASE WHEN p_patient_lat IS NOT NULL THEN distance_km ELSE 999999 END,
        p.trust_score DESC,
        p.verified_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION search_verified_practitioners TO anon;
GRANT EXECUTE ON FUNCTION search_verified_practitioners TO authenticated;
GRANT EXECUTE ON FUNCTION get_practitioner_profile_for_patient TO anon;
GRANT EXECUTE ON FUNCTION get_practitioner_profile_for_patient TO authenticated;

-- ==================================================
-- COMMENTS
-- ==================================================

COMMENT ON FUNCTION get_verification_badge IS 'Generate HTML badge for practitioner verification status';
COMMENT ON FUNCTION is_practitioner_verified IS 'Check if practitioner is currently verified';
COMMENT ON FUNCTION get_practitioner_profile_for_patient IS 'Get practitioner profile for patient view (address hidden)';
COMMENT ON FUNCTION search_verified_practitioners IS 'Search for verified practitioners with filters and distance calculation';
