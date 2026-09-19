-- ==================================================
-- AI DOCUMENT EXTRACTION & VERIFICATION SERVICE
-- ==================================================
-- This file creates a Supabase Edge Function for processing
-- uploaded documents using xAI/Grok for practitioner verification

-- ==================================================
-- PHASE 10: AI DOCUMENT EXTRACTION
-- ==================================================

-- Create function to process document with AI
CREATE OR REPLACE FUNCTION process_document_with_ai(
    p_document_id UUID,
    p_practitioner_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_document documents;
    v_practitioner practitioners;
    v_extraction_result JSONB;
BEGIN
    -- Get document details
    SELECT * INTO v_document FROM documents WHERE id = p_document_id;
    SELECT * INTO v_practitioner FROM practitioners WHERE id = p_practitioner_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Document or practitioner not found';
    END IF;
    
    -- Mark as attempted
    UPDATE documents 
    SET ai_extraction_attempted_at = NOW()
    WHERE id = p_document_id;
    
    -- NOTE: Actual AI extraction happens in Edge Function
    -- This function just tracks the process
    
    RETURN jsonb_build_object(
        'status', 'queued',
        'document_id', p_document_id,
        'document_type', v_document.document_type
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================================================
-- PHASE 11: AI VERIFICATION ASSISTANT
-- ==================================================

-- Function to compare extracted data with profile
CREATE OR REPLACE FUNCTION compare_ai_extraction_with_profile(
    p_practitioner_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_practitioner practitioners;
    v_extraction ai_document_extractions;
    v_name_match_score INTEGER;
    v_reg_match_score INTEGER;
    v_overall_score INTEGER;
    v_discrepancies JSONB := '[]'::JSONB;
BEGIN
    -- Get practitioner details
    SELECT * INTO v_practitioner FROM practitioners WHERE id = p_practitioner_id;
    
    -- Get AI extraction (from registration certificate)
    SELECT * INTO v_extraction 
    FROM ai_document_extractions 
    WHERE practitioner_id = p_practitioner_id 
    ORDER BY extracted_at DESC 
    LIMIT 1;
    
    IF v_extraction IS NULL THEN
        RETURN jsonb_build_object(
            'status', 'no_extraction',
            'message', 'No AI extraction data found'
        );
    END IF;
    
    -- Calculate name match score
    v_name_match_score := CASE
        WHEN LOWER(v_extraction.extracted_full_name) = LOWER(v_practitioner.full_name) THEN 100
        WHEN LOWER(v_extraction.extracted_full_name) LIKE '%' || LOWER(v_practitioner.full_name) || '%' THEN 80
        WHEN LOWER(v_practitioner.full_name) LIKE '%' || LOWER(v_extraction.extracted_full_name) || '%' THEN 80
        ELSE 0
    END;
    
    -- Calculate registration number match
    v_reg_match_score := CASE
        WHEN v_extraction.extracted_registration_number = v_practitioner.registration_number THEN 100
        WHEN v_extraction.extracted_registration_number LIKE '%' || v_practitioner.registration_number || '%' THEN 70
        ELSE 0
    END;
    
    -- Calculate overall match score
    v_overall_score := (v_name_match_score + v_reg_match_score) / 2;
    
    -- Identify discrepancies
    IF v_name_match_score < 90 THEN
        v_discrepancies := v_discrepancies || jsonb_build_object(
            'field', 'name',
            'profile_value', v_practitioner.full_name,
            'extracted_value', v_extraction.extracted_full_name,
            'severity', 'high'
        );
    END IF;
    
    IF v_reg_match_score < 90 THEN
        v_discrepancies := v_discrepancies || jsonb_build_object(
            'field', 'registration_number',
            'profile_value', v_practitioner.registration_number,
            'extracted_value', v_extraction.extracted_registration_number,
            'severity', 'critical'
        );
    END IF;
    
    -- Update extraction record with match scores
    UPDATE ai_document_extractions
    SET 
        name_match_score = v_name_match_score,
        registration_match_score = v_reg_match_score,
        overall_match_score = v_overall_score,
        discrepancies = v_discrepancies
    WHERE id = v_extraction.id;
    
    -- Update verification request with AI insights
    UPDATE verification_requests
    SET 
        ai_confidence_score = v_overall_score,
        ai_discrepancies = v_discrepancies
    WHERE practitioner_id = p_practitioner_id
    AND status IN ('pending_review', 'under_review');
    
    RETURN jsonb_build_object(
        'status', 'success',
        'overall_match_score', v_overall_score,
        'name_match_score', v_name_match_score,
        'registration_match_score', v_reg_match_score,
        'discrepancies', v_discrepancies
    );
END;
$$ LANGUAGE plpgsql;

-- ==================================================
-- Helper function to extract text from documents
-- This would be called by the Edge Function
-- ==================================================

-- Store AI extraction results
CREATE OR REPLACE FUNCTION store_ai_extraction(
    p_document_id UUID,
    p_practitioner_id UUID,
    p_extracted_data JSONB,
    p_model_used TEXT DEFAULT 'grok-2-vision'
)
RETURNS UUID AS $$
DECLARE
    v_extraction_id UUID;
BEGIN
    INSERT INTO ai_document_extractions (
        document_id,
        practitioner_id,
        extracted_full_name,
        extracted_registration_number,
        extracted_profession,
        extracted_institution,
        extracted_qualification,
        extracted_issue_date,
        extracted_expiry_date,
        extraction_confidence,
        raw_extraction,
        model_used
    ) VALUES (
        p_document_id,
        p_practitioner_id,
        p_extracted_data->>'full_name',
        p_extracted_data->>'registration_number',
        p_extracted_data->>'profession',
        p_extracted_data->>'institution',
        p_extracted_data->>'qualification',
        (p_extracted_data->>'issue_date')::DATE,
        (p_extracted_data->>'expiry_date')::DATE,
        (p_extracted_data->>'confidence')::DECIMAL,
        p_extracted_data,
        p_model_used
    )
    ON CONFLICT (document_id) DO UPDATE SET
        extracted_full_name = EXCLUDED.extracted_full_name,
        extracted_registration_number = EXCLUDED.extracted_registration_number,
        extracted_profession = EXCLUDED.extracted_profession,
        extracted_institution = EXCLUDED.extracted_institution,
        extracted_qualification = EXCLUDED.extracted_qualification,
        extracted_issue_date = EXCLUDED.extracted_issue_date,
        extracted_expiry_date = EXCLUDED.extracted_expiry_date,
        extraction_confidence = EXCLUDED.extraction_confidence,
        raw_extraction = EXCLUDED.raw_extraction,
        model_used = EXCLUDED.model_used,
        extracted_at = NOW()
    RETURNING id INTO v_extraction_id;
    
    -- Mark document as AI extracted
    UPDATE documents
    SET ai_extracted = true
    WHERE id = p_document_id;
    
    -- Run comparison with profile
    PERFORM compare_ai_extraction_with_profile(p_practitioner_id);
    
    RETURN v_extraction_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================================================
-- COMMENTS
-- ==================================================

COMMENT ON FUNCTION process_document_with_ai IS 'Queue document for AI processing with xAI/Grok';
COMMENT ON FUNCTION compare_ai_extraction_with_profile IS 'Compare AI-extracted data against practitioner profile';
COMMENT ON FUNCTION store_ai_extraction IS 'Store AI extraction results and trigger verification comparison';
