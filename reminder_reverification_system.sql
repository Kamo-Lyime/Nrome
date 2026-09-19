-- ==================================================
-- REMINDER & REVERIFICATION SYSTEM
-- ==================================================
-- Phase 12 & 13: Automated reminders and reverification workflow

-- ==================================================
-- PHASE 12: REMINDER SYSTEM
-- ==================================================

-- Function to find practitioners needing reminders
CREATE OR REPLACE FUNCTION get_practitioners_needing_reminders()
RETURNS TABLE (
    practitioner_id UUID,
    user_id UUID,
    full_name TEXT,
    verification_status TEXT,
    days_since_creation INTEGER,
    reminder_type TEXT
) AS $$
BEGIN
    RETURN QUERY
    -- Incomplete applications (draft or pending_documents) older than 7 days
    SELECT 
        p.id as practitioner_id,
        p.user_id,
        p.full_name,
        p.verification_status,
        EXTRACT(DAY FROM NOW() - p.created_at)::INTEGER as days_since_creation,
        'incomplete_application'::TEXT as reminder_type
    FROM practitioners p
    WHERE p.verification_status IN ('draft', 'pending_documents')
    AND p.created_at < NOW() - INTERVAL '7 days'
    AND NOT EXISTS (
        -- Check if reminder was sent in last 7 days
        SELECT 1 FROM verification_audit
        WHERE practitioner_id = p.id
        AND action = 'reminder_sent_incomplete'
        AND created_at > NOW() - INTERVAL '7 days'
    )
    
    UNION ALL
    
    -- Verifications expiring soon (within 30 days)
    SELECT 
        p.id as practitioner_id,
        p.user_id,
        p.full_name,
        p.verification_status,
        EXTRACT(DAY FROM p.verification_expires_at - NOW())::INTEGER as days_since_creation,
        'expiring_soon'::TEXT as reminder_type
    FROM practitioners p
    WHERE p.verification_status = 'verified'
    AND p.verification_expires_at IS NOT NULL
    AND p.verification_expires_at BETWEEN NOW() AND NOW() + INTERVAL '30 days'
    AND NOT EXISTS (
        SELECT 1 FROM verification_audit
        WHERE practitioner_id = p.id
        AND action = 'reminder_sent_expiring'
        AND created_at > NOW() - INTERVAL '30 days'
    );
END;
$$ LANGUAGE plpgsql;

-- Function to send reminder
CREATE OR REPLACE FUNCTION send_verification_reminder(
    p_practitioner_id UUID,
    p_reminder_type TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
    v_practitioner practitioners;
BEGIN
    SELECT * INTO v_practitioner FROM practitioners WHERE id = p_practitioner_id;
    
    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;
    
    -- Create audit log
    INSERT INTO verification_audit (
        practitioner_id,
        action,
        notes
    ) VALUES (
        p_practitioner_id,
        'reminder_sent_' || p_reminder_type,
        CASE 
            WHEN p_reminder_type = 'incomplete_application' THEN 
                'Reminder sent: Please complete your verification application'
            WHEN p_reminder_type = 'expiring_soon' THEN 
                'Reminder sent: Your verification is expiring soon. Please reverify.'
            ELSE 'Reminder sent'
        END
    );
    
    -- In production, this would trigger an email/notification
    -- For now, just log it
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- ==================================================
-- PHASE 13: REVERIFICATION WORKFLOW
-- ==================================================

-- Function to check and expire verifications
CREATE OR REPLACE FUNCTION expire_old_verifications()
RETURNS TABLE (
    practitioner_id UUID,
    full_name TEXT,
    expired_at TIMESTAMPTZ
) AS $$
BEGIN
    -- Update expired verifications
    UPDATE practitioners
    SET verification_status = 'expired'
    WHERE verification_status = 'verified'
    AND verification_expires_at < NOW();
    
    -- Log expiration
    INSERT INTO verification_audit (
        practitioner_id,
        action,
        previous_status,
        new_status,
        notes
    )
    SELECT 
        p.id,
        'verification_expired_automatically',
        'verified',
        'expired',
        'Verification expired after 12 months. Reverification required.'
    FROM practitioners p
    WHERE p.verification_status = 'expired'
    AND p.verified_at < NOW() - INTERVAL '12 months'
    AND NOT EXISTS (
        SELECT 1 FROM verification_audit
        WHERE practitioner_id = p.id
        AND action = 'verification_expired_automatically'
        AND created_at > NOW() - INTERVAL '1 day'
    );
    
    -- Return expired practitioners
    RETURN QUERY
    SELECT 
        p.id,
        p.full_name,
        p.verification_expires_at
    FROM practitioners p
    WHERE p.verification_status = 'expired'
    AND p.verification_expires_at < NOW()
    ORDER BY p.verification_expires_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to initiate reverification
CREATE OR REPLACE FUNCTION initiate_reverification(
    p_practitioner_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_practitioner practitioners;
BEGIN
    SELECT * INTO v_practitioner FROM practitioners WHERE id = p_practitioner_id;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('status', 'error', 'message', 'Practitioner not found');
    END IF;
    
    -- Update status to pending_review (they need to reupload documents)
    UPDATE practitioners
    SET 
        verification_status = 'pending_documents',
        updated_at = NOW()
    WHERE id = p_practitioner_id;
    
    -- Create new verification request
    INSERT INTO verification_requests (
        practitioner_id,
        status
    ) VALUES (
        p_practitioner_id,
        'pending_review'
    );
    
    -- Create audit log
    INSERT INTO verification_audit (
        practitioner_id,
        action,
        previous_status,
        new_status,
        notes
    ) VALUES (
        p_practitioner_id,
        'reverification_initiated',
        v_practitioner.verification_status,
        'pending_documents',
        'Reverification process initiated. Practitioner needs to resubmit documents.'
    );
    
    RETURN jsonb_build_object(
        'status', 'success',
        'message', 'Reverification initiated',
        'practitioner_id', p_practitioner_id
    );
END;
$$ LANGUAGE plpgsql;

-- ==================================================
-- SCHEDULED JOBS (To be run via pg_cron or Supabase scheduled functions)
-- ==================================================

-- Example: Run daily to expire old verifications
-- SELECT * FROM expire_old_verifications();

-- Example: Run daily to send reminders
-- SELECT send_verification_reminder(practitioner_id, reminder_type) 
-- FROM get_practitioners_needing_reminders();

-- ==================================================
-- ANALYTICS VIEWS FOR MONITORING
-- ==================================================

CREATE OR REPLACE VIEW verification_reminder_stats AS
SELECT 
    COUNT(*) FILTER (WHERE verification_status = 'draft') as draft_count,
    COUNT(*) FILTER (WHERE verification_status = 'pending_documents') as pending_docs_count,
    COUNT(*) FILTER (WHERE verification_status = 'verified' AND verification_expires_at < NOW() + INTERVAL '30 days') as expiring_soon_count,
    COUNT(*) FILTER (WHERE verification_status = 'expired') as expired_count,
    AVG(EXTRACT(DAY FROM NOW() - created_at)) FILTER (WHERE verification_status IN ('draft', 'pending_documents')) as avg_days_incomplete
FROM practitioners;

COMMENT ON VIEW verification_reminder_stats IS 'Statistics for reminder system monitoring';

-- View for practitioners needing attention
CREATE OR REPLACE VIEW practitioners_needing_attention AS
SELECT 
    p.id,
    p.full_name,
    p.verification_status,
    p.created_at,
    p.verification_expires_at,
    EXTRACT(DAY FROM NOW() - p.created_at)::INTEGER as days_since_creation,
    EXTRACT(DAY FROM p.verification_expires_at - NOW())::INTEGER as days_until_expiry,
    CASE 
        WHEN p.verification_status IN ('draft', 'pending_documents') 
             AND p.created_at < NOW() - INTERVAL '7 days' 
        THEN true 
        ELSE false 
    END as needs_completion_reminder,
    CASE 
        WHEN p.verification_status = 'verified' 
             AND p.verification_expires_at BETWEEN NOW() AND NOW() + INTERVAL '30 days' 
        THEN true 
        ELSE false 
    END as needs_expiry_reminder,
    CASE 
        WHEN p.verification_status = 'verified' 
             AND p.verification_expires_at < NOW() 
        THEN true 
        ELSE false 
    END as needs_expiration
FROM practitioners p
WHERE 
    (p.verification_status IN ('draft', 'pending_documents') AND p.created_at < NOW() - INTERVAL '7 days')
    OR (p.verification_status = 'verified' AND p.verification_expires_at < NOW() + INTERVAL '30 days')
ORDER BY days_until_expiry ASC NULLS LAST;

COMMENT ON VIEW practitioners_needing_attention IS 'Practitioners requiring reminders or action';

-- ==================================================
-- COMMENTS
-- ==================================================

COMMENT ON FUNCTION get_practitioners_needing_reminders IS 'Get list of practitioners who need reminder emails';
COMMENT ON FUNCTION send_verification_reminder IS 'Send verification reminder and log it';
COMMENT ON FUNCTION expire_old_verifications IS 'Automatically expire verifications older than 12 months';
COMMENT ON FUNCTION initiate_reverification IS 'Start reverification process for expired practitioners';
