let practitionerRecord = null;
let currentUserId = null;
let userRole = 'patient'; // Default role
let currentAppointmentId = null;
let messageSubscription = null;
let currentUserName = '';
let globalMessageSubscription = null;

// View state for history sections (default: show latest only)
let viewState = {
    appointments: 'latest',
    prescriptions: 'latest',
    deliveries: 'latest',
    voiceScribe: 'latest'
};

async function initDashboard() {
    const session = await authHelpers.requireAuth();
    if (!session) return;

    const userId = session.user.id;
    currentUserId = userId;

    // Load practitioner profile first to determine role
    await loadPractitionerProfile(userId);
    
    // Determine user role based on practitioner record
    if (practitionerRecord) {
        userRole = 'practitioner';
    }

    wirePractitionerForm(userId);
    await Promise.all([
        loadAppointments(userId),
        loadPrescriptions(userId),
        loadDeliveries(userId),
        loadVoiceScribeHistory()
    ]);

    // Update UI based on role
    updateDashboardUIForRole();
    
    // Update AI usage preview after initial data load
    renderAIHistory();
    
    // Subscribe to global message updates for badge updates
    subscribeToGlobalMessages();
}

async function loadAppointments(userId, limit = null) {
    const list = document.getElementById('appointmentList');
    
    let query = authHelpers.supabaseClient.from('appointments').select('*');
    
    // If user is a practitioner, show appointments booked WITH them
    // If user is a patient, show appointments MADE BY them
    if (userRole === 'practitioner' && practitionerRecord) {
        query = query.eq('practitioner_id', practitionerRecord.id);
    } else {
        query = query.eq('user_id', userId);
    }
    
    query = query.order('appointment_date', { ascending: false });
    
    // Apply limit if showing latest only
    if (limit || viewState.appointments === 'latest') {
        query = query.limit(limit || 1);
    }
    
    const { data, error } = await query;

    if (error) {
        list.innerHTML = `<div class="text-danger">${error.message}</div>`;
        return;
    }

    // Get total count for badge
    let countQuery = authHelpers.supabaseClient.from('appointments').select('id', { count: 'exact', head: true });
    if (userRole === 'practitioner' && practitionerRecord) {
        countQuery = countQuery.eq('practitioner_id', practitionerRecord.id);
    } else {
        countQuery = countQuery.eq('user_id', userId);
    }
    const { count } = await countQuery;
    
    document.getElementById('appointmentCount').textContent = count || 0;

    if (!data.length) {
        const emptyMsg = userRole === 'practitioner' 
            ? 'No patient bookings yet.' 
            : 'No appointments yet.';
        list.innerHTML = `<div class="text-muted">${emptyMsg}</div>`;
        return;
    }

    // Get unread message counts for all appointments
    const unreadCounts = await getUnreadMessageCounts(data.map(item => item.id));

    list.innerHTML = data.map(item => {
        // Show different info based on role
        const mainInfo = userRole === 'practitioner'
            ? `<strong>Patient: ${item.patient_name}</strong>
               <div class="small text-muted">Phone: ${item.patient_phone}</div>
               ${item.patient_email ? `<div class="small text-muted">Email: ${item.patient_email}</div>` : ''}`
            : `<strong>${item.practitioner_name}</strong>
               <div class="small text-muted">${item.reason_for_visit || 'General consult'}</div>`;
        
        const actionButtons = userRole === 'practitioner'
            ? `<button class="btn btn-sm btn-success mt-2 me-1" onclick="updateAppointmentStatus('${item.id}', 'confirmed')">✓ Confirm</button>
               <button class="btn btn-sm btn-warning mt-2 me-1" onclick="updateAppointmentStatus('${item.id}', 'rescheduled')">↻ Reschedule</button>
               <button class="btn btn-sm btn-danger mt-2" onclick="updateAppointmentStatus('${item.id}', 'cancelled')">✗ Cancel</button>`
            : '';
        
        // Get unread count for this appointment
        const unreadCount = unreadCounts[item.id] || 0;
        const unreadBadge = unreadCount > 0 
            ? `<span class="badge bg-danger ms-1">${unreadCount}</span>` 
            : '';
        
        // Add message button for confirmed appointments (visible to both patient and practitioner)
        const messageButton = item.status === 'confirmed'
            ? `<button class="btn btn-sm btn-primary mt-2 position-relative" onclick="openMessagesModal('${item.id}', '${item.practitioner_name}', '${item.patient_name}', '${item.appointment_date}')" id="msgBtn-${item.id}">
                 <i class="fas fa-comments me-1"></i>Messages${unreadBadge}
               </button>`
            : '';
        
        // Show reschedule info if status is rescheduled
        const rescheduleInfo = item.status === 'rescheduled' && item.rescheduled_date
            ? `<div class="alert alert-warning mt-2 mb-0 py-2 px-3 small">
                 <strong>↻ Rescheduled to:</strong> ${new Date(item.rescheduled_date).toLocaleDateString()} at ${item.rescheduled_time}
                 ${item.practitioner_notes ? `<br><strong>Note:</strong> ${item.practitioner_notes}` : ''}
               </div>`
            : '';
        
        // Show cancellation reason if cancelled
        const cancellationInfo = item.status === 'cancelled' && item.cancellation_reason
            ? `<div class="alert alert-danger mt-2 mb-0 py-2 px-3 small">
                 <strong>✗ Cancellation Reason:</strong> ${item.cancellation_reason}
               </div>`
            : '';
        
        // Show AI scheduling suggestion if available
        const aiSuggestionInfo = item.ai_scheduling_suggestion
            ? `<div class="alert alert-info mt-2 mb-0 py-2 px-3 small">
                 <strong>🤖 AI Scheduling Recommendation:</strong><br>
                 ${item.ai_scheduling_suggestion}
               </div>`
            : '';
        
        return `
            <div class="border rounded p-3 mb-2">
                <div class="d-flex justify-content-between">
                    <div>
                        ${mainInfo}
                    </div>
                    <span class="badge bg-${getStatusBadgeColor(item.status)}">${item.status}</span>
                </div>
                <div class="small mt-2"><strong>📅 ${new Date(item.appointment_date).toLocaleDateString()} at ${item.appointment_time}</strong></div>
                <div class="small text-muted">Type: ${item.appointment_type}</div>
                ${item.reason_for_visit && userRole === 'practitioner' ? `<div class="small mt-1"><strong>Reason:</strong> ${item.reason_for_visit}</div>` : ''}
                ${item.reason_for_visit && userRole === 'patient' ? `<div class="small mt-1"><strong>Reason:</strong> ${item.reason_for_visit}</div>` : ''}
                <div class="small text-muted">Booking ID: ${item.booking_id}</div>
                ${aiSuggestionInfo}
                ${rescheduleInfo}
                ${cancellationInfo}
                <div class="mt-2">
                    ${actionButtons}
                    ${messageButton}
                </div>
            </div>
        `;
    }).join('');
}

function getStatusBadgeColor(status) {
    const colors = {
        'confirmed': 'success',
        'pending': 'warning',
        'cancelled': 'danger',
        'completed': 'info',
        'rescheduled': 'secondary'
    };
    return colors[status] || 'primary';
}

async function updateAppointmentStatus(appointmentId, newStatus) {
    let updateData = { status: newStatus };
    
    // Handle rescheduling - collect new date and time
    if (newStatus === 'rescheduled') {
        const newDate = prompt('Enter new appointment date (YYYY-MM-DD):');
        if (!newDate) return; // User cancelled
        
        const newTime = prompt('Enter new appointment time (HH:MM):');
        if (!newTime) return; // User cancelled
        
        // Validate date format
        if (!/^\d{4}-\d{2}-\d{2}$/.test(newDate)) {
            alert('Invalid date format. Please use YYYY-MM-DD (e.g., 2026-02-15)');
            return;
        }
        
        // Validate time format
        if (!/^\d{2}:\d{2}$/.test(newTime)) {
            alert('Invalid time format. Please use HH:MM (e.g., 14:30)');
            return;
        }
        
        const notes = prompt('Optional: Add notes about the reschedule (or leave blank):') || '';
        
        if (!confirm(`Reschedule appointment to ${newDate} at ${newTime}?`)) {
            return;
        }
        
        updateData = {
            status: newStatus,
            rescheduled_date: newDate,
            rescheduled_time: newTime,
            practitioner_notes: notes
        };
    }
    // Handle cancellation - collect reason
    else if (newStatus === 'cancelled') {
        const reason = prompt('Please provide a reason for cancellation (this will be visible to the patient):');
        if (!reason) {
            alert('A cancellation reason is required.');
            return;
        }
        
        if (!confirm(`Cancel this appointment?\n\nReason: ${reason}`)) {
            return;
        }
        
        updateData = {
            status: newStatus,
            cancellation_reason: reason
        };
    }
    // Handle confirmation
    else if (newStatus === 'confirmed') {
        if (!confirm('Confirm this appointment?')) {
            return;
        }
    }
    else {
        if (!confirm(`Are you sure you want to mark this appointment as ${newStatus}?`)) {
            return;
        }
    }
    
    const { error } = await authHelpers.supabaseClient
        .from('appointments')
        .update(updateData)
        .eq('id', appointmentId);
    
    if (error) {
        alert('Error updating appointment: ' + error.message);
        return;
    }
    
    alert('Appointment status updated successfully!');
    loadAppointments(currentUserId);
}

function updateDashboardUIForRole() {
    const appointmentSection = document.querySelector('#appointmentList').closest('.card');
    const sectionTitle = appointmentSection?.querySelector('.card-header h5');
    
    if (sectionTitle) {
        if (userRole === 'practitioner') {
            sectionTitle.innerHTML = '📅 Patient Appointments Booked With You';
        } else {
            sectionTitle.innerHTML = '📅 Your Appointments';
        }
    }
}

async function loadPrescriptions(userId, limit = null) {
    const container = document.getElementById('prescriptionListDashboard');
    
    let query = authHelpers.supabaseClient.from('prescriptions').select('*');
    
    // If practitioner, show prescriptions they uploaded
    // If patient, show prescriptions for them
    if (userRole === 'practitioner' && practitionerRecord) {
        query = query.eq('practitioner_id', practitionerRecord.id);
    } else {
        query = query.eq('user_id', userId);
    }
    
    query = query.order('upload_date', { ascending: false });
    
    // Apply limit if showing latest only
    if (limit || viewState.prescriptions === 'latest') {
        query = query.limit(limit || 1);
    }
    
    const { data, error } = await query;

    if (error) {
        container.innerHTML = `<div class="text-danger">${error.message}</div>`;
        return;
    }

    // Get total count for badge
    let countQuery = authHelpers.supabaseClient.from('prescriptions').select('id', { count: 'exact', head: true });
    if (userRole === 'practitioner' && practitionerRecord) {
        countQuery = countQuery.eq('practitioner_id', practitionerRecord.id);
    } else {
        countQuery = countQuery.eq('user_id', userId);
    }
    const { count } = await countQuery;
    
    document.getElementById('prescriptionCount').textContent = count || 0;

    if (!data.length) {
        const emptyMsg = userRole === 'practitioner'
            ? 'No prescriptions uploaded yet. Click "Add Prescription" button above to upload for a patient.'
            : 'No prescriptions uploaded.';
        container.innerHTML = `<div class="text-muted">${emptyMsg}</div>`;
        return;
    }

    container.innerHTML = data.map(rx => {
        const mainInfo = userRole === 'practitioner'
            ? `<strong>Patient: ${rx.patient_name || 'Unknown'}</strong>
               <div class="small text-muted">Doctor: ${rx.doctor_name}</div>
               ${rx.patient_email ? `<div class="small text-muted">Email: ${rx.patient_email}</div>` : ''}`
            : `<strong>Dr. ${rx.doctor_name}</strong>
               ${rx.practitioner_id ? `<div class="small text-muted">Uploaded by practitioner</div>` : ''}
               <div class="small text-muted">${new Date(rx.prescription_date).toLocaleDateString()}</div>`;
        
        const viewButton = `<button class="btn btn-sm btn-outline-primary mt-2" onclick="viewPrescription('${rx.id}')">👁️ View</button>`;
        
        return `
            <div class="border rounded p-3 mb-2">
                <div class="d-flex justify-content-between align-items-center">
                    <div>
                        ${mainInfo}
                    </div>
                    <span class="badge ${rx.verified ? 'bg-success' : 'bg-warning text-dark'}">${rx.status}</span>
                </div>
                <div class="small mt-1">File: ${rx.file_name}</div>
                ${rx.notes ? `<div class="small text-muted mt-1">Notes: ${rx.notes}</div>` : ''}
                ${viewButton}
            </div>
        `;
    }).join('');
    
    // Update section title
    updatePrescriptionSectionTitle();
}

function updatePrescriptionSectionTitle() {
    const prescriptionSection = document.querySelector('#prescriptionListDashboard')?.closest('.card');
    const sectionTitle = prescriptionSection?.querySelector('.card-header h5');
    const uploadBtn = document.getElementById('uploadPrescriptionBtn');
    
    if (sectionTitle) {
        if (userRole === 'practitioner') {
            sectionTitle.innerHTML = '<i class="fas fa-file-prescription me-2"></i>Patient Prescriptions Uploaded';
            // Show upload button for practitioners
            if (uploadBtn) {
                uploadBtn.style.display = 'inline-block';
            }
        } else {
            sectionTitle.innerHTML = '<i class="fas fa-file-prescription me-2"></i>My Prescriptions';
            // Hide upload button for patients
            if (uploadBtn) {
                uploadBtn.style.display = 'none';
            }
        }
    }
}

async function loadDeliveries(userId, limit = null) {
    const container = document.getElementById('deliveryList');
    
    let query = authHelpers.supabaseClient
        .from('medication_orders')
        .select('*')
        .eq('user_id', userId)
        .order('order_date', { ascending: false });
    
    // Apply limit if showing latest only
    if (limit || viewState.deliveries === 'latest') {
        query = query.limit(limit || 1);
    }
    
    const { data, error } = await query;

    if (error) {
        container.innerHTML = `<div class="text-danger">${error.message}</div>`;
        return;
    }

    // Get total count for badge
    const { count } = await authHelpers.supabaseClient
        .from('medication_orders')
        .select('id', { count: 'exact', head: true })
        .eq('user_id', userId);
    
    document.getElementById('deliveryCount').textContent = count || 0;

    if (!data.length) {
        container.innerHTML = '<div class="text-muted">No delivery requests yet.</div>';
        return;
    }

    container.innerHTML = data.map(order => `
        <div class="border rounded p-3 mb-2">
            <div class="d-flex justify-content-between align-items-center">
                <div>
                    <strong>${order.patient_name}</strong>
                    <div class="small text-muted">${new Date(order.delivery_date).toLocaleDateString()}</div>
                </div>
                <span class="badge bg-info text-dark">${order.status}</span>
            </div>
            <div class="small">Medications: ${Array.isArray(order.medications) ? order.medications.length : ''}</div>
        </div>
    `).join('');
}

async function loadPractitionerProfile(userId) {
    const feedback = document.getElementById('practitionerFeedback');
    try {
        const { data, error } = await authHelpers.supabaseClient
            .from('medical_practitioners')
            .select('*')
            .eq('owner_user_id', userId)
            .limit(1)
            .maybeSingle();

        if (error && error.code !== 'PGRST116') {
            feedback.textContent = error.message;
            feedback.classList.remove('text-muted');
            feedback.classList.add('text-danger');
            return;
        }

        if (data) {
            practitionerRecord = data;
            fillPractitionerForm(data);
            feedback.textContent = 'Loaded your profile.';
            feedback.classList.remove('text-danger');
            feedback.classList.add('text-success');
        } else {
            feedback.textContent = 'No profile yet. Create one below.';
            feedback.classList.remove('text-danger');
            feedback.classList.add('text-muted');
        }
    } catch (err) {
        feedback.textContent = err.message;
        feedback.classList.remove('text-muted');
        feedback.classList.add('text-danger');
    }
}

function fillPractitionerForm(data) {
    document.getElementById('practitionerName').value = data.name || '';
    document.getElementById('practitionerProfession').value = data.profession || '';
    document.getElementById('practitionerLicense').value = data.license_number || '';
    document.getElementById('practitionerDescription').value = data.service_description || '';
    document.getElementById('practitionerFee').value = data.consultation_fee || '';
    document.getElementById('practitionerCurrency').value = data.currency || '';
    document.getElementById('practitionerLocations').value = data.serving_locations || '';
    document.getElementById('practitionerAvailability').value = data.availability || '';
    document.getElementById('practitionerPhone').value = data.phone_number || '';
    document.getElementById('practitionerEmail').value = data.email_address || '';
}

function wirePractitionerForm(userId) {
    const form = document.getElementById('practitionerForm');
    if (!form) return;

    form.addEventListener('submit', async (e) => {
        e.preventDefault();
        const feedback = document.getElementById('practitionerFeedback');
        feedback.textContent = 'Saving...';
        feedback.classList.remove('text-danger');
        feedback.classList.remove('text-success');
        feedback.classList.add('text-muted');

        const payload = {
            owner_user_id: userId,
            name: document.getElementById('practitionerName').value.trim(),
            profession: document.getElementById('practitionerProfession').value.trim(),
            license_number: document.getElementById('practitionerLicense').value.trim() || null,
            service_description: document.getElementById('practitionerDescription').value.trim() || null,
            consultation_fee: parseFloat(document.getElementById('practitionerFee').value) || null,
            currency: document.getElementById('practitionerCurrency').value.trim() || null,
            serving_locations: document.getElementById('practitionerLocations').value.trim() || null,
            availability: document.getElementById('practitionerAvailability').value.trim() || null,
            phone_number: document.getElementById('practitionerPhone').value.trim() || null,
            email_address: document.getElementById('practitionerEmail').value.trim() || null
        };

        try {
            if (practitionerRecord?.id) {
                const { error } = await authHelpers.supabaseClient
                    .from('medical_practitioners')
                    .update(payload)
                    .eq('id', practitionerRecord.id);

                if (error) throw error;
            } else {
                payload.created_at = new Date().toISOString();
                const { data, error } = await authHelpers.supabaseClient
                    .from('medical_practitioners')
                    .insert([payload])
                    .select()
                    .single();

                if (error) throw error;
                practitionerRecord = data;
            }

            feedback.textContent = 'Profile saved.';
            feedback.classList.remove('text-danger');
            feedback.classList.remove('text-muted');
            feedback.classList.add('text-success');
        } catch (err) {
            feedback.textContent = err.message;
            feedback.classList.remove('text-muted');
            feedback.classList.remove('text-success');
            feedback.classList.add('text-danger');
        }
    });
}

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initDashboard);
} else {
    initDashboard();
}

// ---------------------------
// AI Usage History (local per user)
// ---------------------------

const AI_HISTORY_KEY = 'ai_usage_history_v1';

function safeGetItem(key) {
    try {
        return localStorage.getItem(key);
    } catch (err) {
        console.warn('Storage get blocked:', err);
        return null;
    }
}

function safeSetItem(key, value) {
    try {
        localStorage.setItem(key, value);
        return true;
    } catch (err) {
        console.warn('Storage set blocked:', err);
        return false;
    }
}

function getAIHistory() {
    const raw = safeGetItem(AI_HISTORY_KEY);
    if (!raw) return [];
    try {
        return JSON.parse(raw) || [];
    } catch (err) {
        console.warn('AI history parse error:', err);
        return [];
    }
}

function saveAIHistory(history) {
    safeSetItem(AI_HISTORY_KEY, JSON.stringify(history.slice(-200)));
}

async function renderAIHistory() {
    const modalList = document.getElementById('aiHistoryList');
    const previewList = document.getElementById('aiHistoryPreview');
    if (!modalList && !previewList) return;

    const userId = currentUserId || 'guest';
    const supabaseClient = authHelpers?.supabaseClient;
    let history = [];

    if (supabaseClient && userId && userId !== 'guest') {
        try {
            const { data, error } = await supabaseClient
                .from('ai_usage_logs')
                .select('*')
                .eq('user_id', userId)
                .order('created_at', { ascending: false })
                .limit(200);
            if (!error) {
                history = (data || []).map(row => ({
                    ts: row.created_at,
                    type: row.feature,
                    payload: row.payload,
                    input: row.input_text,
                    output: row.output_text
                }));
            } else {
                console.warn('AI history Supabase fetch error, using local:', error.message);
            }
        } catch (err) {
            console.warn('AI history Supabase fetch failed, using local:', err.message);
        }
    }

    if (!history.length) {
        history = getAIHistory()
            .filter(h => h.userId === userId)
            .sort((a, b) => b.ts.localeCompare(a.ts));
    }

    const labelForType = (type) => {
        switch (type) {
            case 'chat': return 'AI Medical Assistant';
            case 'triage': return 'Smart Triage';
            case 'appointment': return 'AI Appointment Booking';
            case 'voice-scribe': return 'Voice Medical Scribe';
            default: return type ? type.toString() : 'Other';
        }
    };

    const renderCards = (items) => items.map(item => {
        const timestamp = new Date(item.ts).toLocaleString();
        const heading = labelForType(item.type);
        if (item.type === 'chat') {
            return `
                <div class="border rounded p-2 mb-2">
                    <div class="small text-muted">${heading} — ${timestamp}</div>
                    <div><strong>You:</strong> ${item.payload?.message || item.input || ''}</div>
                    <div class="mt-1"><strong>AI:</strong> ${item.payload?.response || item.output || ''}</div>
                </div>`;
        }
        if (item.type === 'triage') {
            const assessment = item.payload?.assessment || '';
            return `
                <div class="border rounded p-2 mb-2">
                    <div class="small text-muted">${heading} — ${timestamp}</div>
                    <div><strong>Symptoms:</strong> ${item.payload?.symptoms || item.input || ''}</div>
                    <div class="mt-1"><strong>Urgency:</strong> ${item.payload?.urgency || item.output || ''}</div>
                    ${assessment ? `<div class="mt-2 alert alert-light border-start border-primary border-3 mb-0">
                        <small><strong>AI Assessment:</strong></small>
                        <div class="small" style="white-space: pre-wrap;">${assessment}</div>
                    </div>` : ''}
                </div>`;
        }
        return `
            <div class="border rounded p-2 mb-2">
                <div class="small text-muted">${heading} — ${timestamp}</div>
                <div class="mt-1"><strong>Details:</strong> ${JSON.stringify(item.payload || {})}</div>
            </div>`;
    }).join('');

    const groupByFeature = (items) => {
        const groups = {};
        items.forEach(item => {
            const key = labelForType(item.type);
            if (!groups[key]) groups[key] = [];
            groups[key].push(item);
        });
        return Object.entries(groups).map(([label, entries]) => ({ label, entries }));
    };

    if (!history.length) {
        const empty = '<div class="text-muted">No AI usage yet.</div>';
        if (modalList) modalList.innerHTML = empty;
        if (previewList) previewList.innerHTML = empty;
        return;
    }

    const grouped = groupByFeature(history);

    if (modalList) {
        modalList.innerHTML = grouped.map(group => `
            <div class="mb-3">
                <div class="fw-semibold mb-1">${group.label}</div>
                ${renderCards(group.entries)}
            </div>
        `).join('');
    }

    if (previewList) {
        const previewHtml = grouped.map(group => {
            const entries = group.entries.slice(0, 2);
            const more = group.entries.length > 2
                ? `<div class="text-muted small">and ${group.entries.length - 2} more...</div>`
                : '';
            return `
                <div class="mb-2">
                    <div class="fw-semibold">${group.label}</div>
                    ${renderCards(entries)}
                    ${more}
                </div>`;
        }).join('');
        previewList.innerHTML = previewHtml;
    }
}

function openAIHistory() {
    renderAIHistory();
    const modalEl = document.getElementById('aiHistoryModal');
    if (!modalEl) return;
    const modal = new bootstrap.Modal(modalEl, { backdrop: 'static' });
    modal.show();
}

async function clearAIHistory() {
    const userId = currentUserId || 'guest';
    const supabaseClient = authHelpers?.supabaseClient;
    if (supabaseClient && userId && userId !== 'guest') {
        try {
            await supabaseClient.from('ai_usage_logs').delete().eq('user_id', userId);
        } catch (err) {
            console.warn('AI history Supabase delete failed, clearing local only:', err.message);
        }
    }
    const filtered = getAIHistory().filter(h => h.userId !== userId);
    saveAIHistory(filtered);
    renderAIHistory();
}

window.openAIHistory = openAIHistory;
window.clearAIHistory = clearAIHistory;
window.renderAIHistory = renderAIHistory;
window.updateAppointmentStatus = updateAppointmentStatus;
window.viewPrescription = viewPrescription;
window.openUploadPrescriptionModal = openUploadPrescriptionModal;
window.searchPatients = searchPatients;
window.selectPatient = selectPatient;
window.selectManualPatient = selectManualPatient;
window.uploadPrescriptionForPatient = uploadPrescriptionForPatient;

// ---------------------------
// Launch AI features inline (loads nurse tools in an iframe)
// ---------------------------

function openAIFeature(feature) {
    const featureMap = {
        appointment: { hash: 'open=appointment', title: 'AI Appointment Booking' },
        'medical-assistant': { hash: 'open=medical-assistant', title: 'AI Medical Assistant' },
        'voice-scribe': { hash: 'open=voice-scribe', title: 'Voice Medical Scribe' },
        'smart-triage': { hash: 'open=smart-triage', title: 'Smart Triage' }
    };

    const config = featureMap[feature];
    const frame = document.getElementById('aiFeatureFrame');
    const modalEl = document.getElementById('aiFeatureModal');
    const titleEl = modalEl?.querySelector('.modal-title');

    if (!config || !frame || !modalEl) {
        console.warn('AI feature modal not available.');
        return;
    }

    frame.src = `nurse.html?embed=1#${config.hash}`;
    if (titleEl) titleEl.textContent = config.title;

    const modal = new bootstrap.Modal(modalEl, { backdrop: 'static', keyboard: true });
    modal.show();
}

window.openAIFeature = openAIFeature;

// =====================================================
// UNREAD MESSAGE COUNT TRACKING
// =====================================================

/**
 * Get unread message counts for multiple appointments
 */
async function getUnreadMessageCounts(appointmentIds) {
    if (!appointmentIds || appointmentIds.length === 0) return {};
    
    try {
        const { data, error } = await authHelpers.supabaseClient
            .from('appointment_messages')
            .select('appointment_id')
            .in('appointment_id', appointmentIds)
            .neq('sender_id', currentUserId)
            .eq('is_read', false);
        
        if (error) throw error;
        
        // Count unread messages per appointment
        const counts = {};
        data.forEach(msg => {
            counts[msg.appointment_id] = (counts[msg.appointment_id] || 0) + 1;
        });
        
        return counts;
        
    } catch (error) {
        console.error('Error getting unread counts:', error);
        return {};
    }
}

/**
 * Update the unread badge on a specific message button
 */
async function updateMessageButtonBadge(appointmentId) {
    const button = document.getElementById(`msgBtn-${appointmentId}`);
    if (!button) return;
    
    try {
        const { data, error } = await authHelpers.supabaseClient
            .from('appointment_messages')
            .select('id')
            .eq('appointment_id', appointmentId)
            .neq('sender_id', currentUserId)
            .eq('is_read', false);
        
        if (error) throw error;
        
        const unreadCount = data.length;
        
        // Find existing badge or create new one
        let badge = button.querySelector('.badge');
        
        if (unreadCount > 0) {
            if (badge) {
                badge.textContent = unreadCount;
            } else {
                button.innerHTML = `<i class="fas fa-comments me-1"></i>Messages<span class="badge bg-danger ms-1">${unreadCount}</span>`;
            }
        } else {
            if (badge) {
                badge.remove();
            }
        }
        
    } catch (error) {
        console.error('Error updating message badge:', error);
    }
}

/**
 * Subscribe to all message updates globally to update badges
 */
function subscribeToGlobalMessages() {
    // Unsubscribe from previous subscription if exists
    if (globalMessageSubscription) {
        globalMessageSubscription.unsubscribe();
    }
    
    // Subscribe to all message changes
    globalMessageSubscription = authHelpers.supabaseClient
        .channel('global-messages')
        .on('postgres_changes', {
            event: '*',
            schema: 'public',
            table: 'appointment_messages'
        }, (payload) => {
            // Update the badge for the affected appointment
            if (payload.new && payload.new.appointment_id) {
                updateMessageButtonBadge(payload.new.appointment_id);
            } else if (payload.old && payload.old.appointment_id) {
                updateMessageButtonBadge(payload.old.appointment_id);
            }
        })
        .subscribe();
}

// =====================================================
// APPOINTMENT MESSAGING FUNCTIONS
// =====================================================

/**
 * Open the messages modal for a specific appointment
 */
async function openMessagesModal(appointmentId, practitionerName, patientName, appointmentDate) {
    currentAppointmentId = appointmentId;
    
    // Set modal title
    const otherPartyName = userRole === 'practitioner' ? patientName : practitionerName;
    document.getElementById('messageModalTitle').textContent = `Messages with ${otherPartyName}`;
    
    // Set appointment info
    const appointmentInfo = document.getElementById('messageAppointmentInfo');
    appointmentInfo.innerHTML = `
        <div class="d-flex justify-content-between align-items-center">
            <div>
                <strong>${userRole === 'practitioner' ? 'Patient' : 'Practitioner'}:</strong> ${otherPartyName}
            </div>
            <div class="text-muted small">
                <i class="fas fa-calendar me-1"></i>${new Date(appointmentDate).toLocaleDateString()}
            </div>
        </div>
    `;
    
    // Get current user name
    if (userRole === 'practitioner' && practitionerRecord) {
        currentUserName = practitionerRecord.name;
    } else {
        currentUserName = patientName; // For patients, use their name from appointment
    }
    
    // Load messages
    await loadMessages(appointmentId);
    
    // Subscribe to real-time updates
    subscribeToMessages(appointmentId);
    
    // Show modal
    const modal = new bootstrap.Modal(document.getElementById('appointmentMessagesModal'));
    modal.show();
    
    // Mark messages as read when modal opens
    markMessagesAsRead(appointmentId);
    
    // Clean up subscription when modal is closed
    document.getElementById('appointmentMessagesModal').addEventListener('hidden.bs.modal', function() {
        if (messageSubscription) {
            messageSubscription.unsubscribe();
            messageSubscription = null;
        }
        currentAppointmentId = null;
    }, { once: true });
}

/**
 * Load messages for an appointment
 */
async function loadMessages(appointmentId) {
    const container = document.getElementById('messagesContainer');
    
    try {
        const { data, error } = await authHelpers.supabaseClient
            .from('appointment_messages')
            .select('*')
            .eq('appointment_id', appointmentId)
            .order('created_at', { ascending: true });
        
        if (error) throw error;
        
        if (!data || data.length === 0) {
            container.innerHTML = `
                <div class="text-center text-muted py-5">
                    <i class="fas fa-comments fa-3x mb-3 opacity-25"></i>
                    <p>No messages yet. Start the conversation!</p>
                </div>
            `;
            return;
        }
        
        // Render messages
        container.innerHTML = data.map(msg => {
            const isCurrentUser = msg.sender_id === currentUserId;
            const alignClass = isCurrentUser ? 'text-end' : 'text-start';
            const bgClass = isCurrentUser ? 'bg-primary text-white' : 'bg-white';
            const messageTime = new Date(msg.created_at).toLocaleString('en-US', {
                month: 'short',
                day: 'numeric',
                hour: '2-digit',
                minute: '2-digit'
            });
            
            return `
                <div class="${alignClass} mb-3">
                    <div class="d-inline-block ${bgClass} rounded px-3 py-2 shadow-sm" style="max-width: 70%;">
                        ${!isCurrentUser ? `<div class="small fw-bold mb-1">${msg.sender_name}</div>` : ''}
                        <div>${escapeHtml(msg.message)}</div>
                        <div class="small opacity-75 mt-1">${messageTime}</div>
                    </div>
                </div>
            `;
        }).join('');
        
        // Scroll to bottom
        container.scrollTop = container.scrollHeight;
        
    } catch (error) {
        console.error('Error loading messages:', error);
        container.innerHTML = `
            <div class="alert alert-danger">
                Error loading messages: ${error.message}
            </div>
        `;
    }
}

/**
 * Send a new message
 */
async function sendMessage(event) {
    event.preventDefault();
    
    const input = document.getElementById('messageInput');
    const message = input.value.trim();
    
    if (!message || !currentAppointmentId) return;
    
    try {
        const messageData = {
            appointment_id: currentAppointmentId,
            sender_id: currentUserId,
            sender_name: currentUserName,
            sender_role: userRole,
            message: message,
            is_read: false
        };
        
        const { error } = await authHelpers.supabaseClient
            .from('appointment_messages')
            .insert([messageData]);
        
        if (error) throw error;
        
        // Clear input
        input.value = '';
        
        // Reload messages
        await loadMessages(currentAppointmentId);
        
    } catch (error) {
        console.error('Error sending message:', error);
        alert('Error sending message: ' + error.message);
    }
}

/**
 * Subscribe to real-time message updates
 */
function subscribeToMessages(appointmentId) {
    // Unsubscribe from previous subscription if exists
    if (messageSubscription) {
        messageSubscription.unsubscribe();
    }
    
    // Subscribe to new messages for this appointment
    messageSubscription = authHelpers.supabaseClient
        .channel(`appointment-messages-${appointmentId}`)
        .on('postgres_changes', {
            event: 'INSERT',
            schema: 'public',
            table: 'appointment_messages',
            filter: `appointment_id=eq.${appointmentId}`
        }, (payload) => {
            // Reload messages when a new message is inserted
            loadMessages(appointmentId);
            
            // Mark as read if modal is open
            if (document.getElementById('appointmentMessagesModal').classList.contains('show')) {
                markMessagesAsRead(appointmentId);
            }
            
            // Update badge on the message button
            updateMessageButtonBadge(appointmentId);
        })
        .subscribe();
}

/**
 * Mark messages as read
 */
async function markMessagesAsRead(appointmentId) {
    try {
        // Mark all unread messages from other users as read
        const { error } = await authHelpers.supabaseClient
            .from('appointment_messages')
            .update({ 
                is_read: true,
                read_at: new Date().toISOString()
            })
            .eq('appointment_id', appointmentId)
            .neq('sender_id', currentUserId)
            .eq('is_read', false);
        
        if (error) throw error;
        
        // Update the badge after marking as read
        updateMessageButtonBadge(appointmentId);
        
    } catch (error) {
        console.error('Error marking messages as read:', error);
    }
}

/**
 * Delete entire conversation
 */
async function deleteConversation() {
    if (!currentAppointmentId) {
        alert('No conversation to delete.');
        return;
    }
    
    const confirmDelete = confirm(
        '⚠️ WARNING: This will permanently delete ALL messages in this conversation.\n\n' +
        'This action cannot be undone and will affect both you and the other person.\n\n' +
        'Are you sure you want to continue?'
    );
    
    if (!confirmDelete) return;
    
    // Double confirmation for safety
    const doubleConfirm = confirm(
        'Final confirmation: Delete ALL messages in this conversation?\n\n' +
        'Click OK to permanently delete, or Cancel to keep the messages.'
    );
    
    if (!doubleConfirm) return;
    
    try {
        const { error } = await authHelpers.supabaseClient
            .from('appointment_messages')
            .delete()
            .eq('appointment_id', currentAppointmentId);
        
        if (error) throw error;
        
        alert('✅ Conversation deleted successfully.');
        
        // Reload messages (will show empty state)
        await loadMessages(currentAppointmentId);
        
        // Update the badge
        updateMessageButtonBadge(currentAppointmentId);
        
        // Close modal
        const modal = bootstrap.Modal.getInstance(document.getElementById('appointmentMessagesModal'));
        modal?.hide();
        
    } catch (error) {
        console.error('Error deleting conversation:', error);
        alert('❌ Error deleting conversation: ' + error.message);
    }
}

/**
 * Escape HTML to prevent XSS
 */
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// Expose messaging functions to global scope
window.openMessagesModal = openMessagesModal;
window.sendMessage = sendMessage;
window.deleteConversation = deleteConversation;

// =====================================================
// PRESCRIPTION MANAGEMENT FOR PRACTITIONERS
// =====================================================

async function viewPrescription(prescriptionId) {
    const modal = document.getElementById('viewPrescriptionModal');
    if (!modal) {
        alert('Prescription viewer not available. Please refresh the page.');
        return;
    }
    
    try {
        // Fetch prescription details
        const { data, error } = await authHelpers.supabaseClient
            .from('prescriptions')
            .select('*')
            .eq('id', prescriptionId)
            .single();
        
        if (error) throw error;
        
        if (!data) {
            alert('Prescription not found.');
            return;
        }
        
        // Populate modal with prescription details
        document.getElementById('viewRxPatientName').textContent = data.patient_name || 'N/A';
        document.getElementById('viewRxPatientEmail').textContent = data.patient_email || 'N/A';
        document.getElementById('viewRxDoctorName').textContent = data.doctor_name || 'N/A';
        document.getElementById('viewRxDate').textContent = data.prescription_date ? new Date(data.prescription_date).toLocaleDateString() : 'N/A';
        document.getElementById('viewRxExpiry').textContent = data.prescription_expiry ? new Date(data.prescription_expiry).toLocaleDateString() : 'Not specified';
        document.getElementById('viewRxRefills').textContent = data.refills_allowed || '0';
        
        // Status badge
        const statusBadge = document.getElementById('viewRxStatus');
        statusBadge.textContent = data.status || 'Unknown';
        statusBadge.className = 'badge ' + (data.verified ? 'bg-success' : 'bg-warning');
        
        document.getElementById('viewRxUploadDate').textContent = data.upload_date ? new Date(data.upload_date).toLocaleDateString() : 'N/A';
        
        // Show practitioner info if uploaded by practitioner
        const practitionerInfo = document.getElementById('viewRxPractitionerInfo');
        if (data.practitioner_id) {
            practitionerInfo.style.display = 'block';
        } else {
            practitionerInfo.style.display = 'none';
        }
        
        // Show notes if present
        const notesSection = document.getElementById('viewRxNotesSection');
        if (data.notes) {
            document.getElementById('viewRxNotes').textContent = data.notes;
            notesSection.style.display = 'block';
        } else {
            notesSection.style.display = 'none';
        }
        
        // Display prescription file
        const fileContainer = document.getElementById('viewRxFileContainer');
        if (data.file_data) {
            const fileExt = data.file_name.toLowerCase().split('.').pop();
            if (fileExt === 'pdf') {
                fileContainer.innerHTML = `
                    <embed src="${data.file_data}" type="application/pdf" width="100%" height="500px" />
                    <div class="mt-2">
                        <a href="${data.file_data}" download="${data.file_name}" class="btn btn-sm btn-primary">
                            <i class="fas fa-download me-1"></i>Download PDF
                        </a>
                    </div>
                `;
            } else {
                fileContainer.innerHTML = `
                    <img src="${data.file_data}" class="img-fluid rounded" alt="Prescription" style="max-height: 500px;">
                    <div class="mt-2">
                        <a href="${data.file_data}" download="${data.file_name}" class="btn btn-sm btn-primary">
                            <i class="fas fa-download me-1"></i>Download Image
                        </a>
                    </div>
                `;
            }
        } else {
            fileContainer.innerHTML = '<div class="text-muted">File not available</div>';
        }
        
        // Open modal
        const bootstrapModal = new bootstrap.Modal(modal);
        bootstrapModal.show();
        
    } catch (error) {
        console.error('View prescription error:', error);
        alert('Error loading prescription: ' + error.message);
    }
}

let selectedPatientForPrescription = null;

function openUploadPrescriptionModal() {
    const modal = document.getElementById('uploadPrescriptionModal');
    if (!modal) {
        alert('Upload prescription feature is being set up. Please refresh the page.');
        return;
    }
    
    // Reset form
    document.getElementById('prescriptionUploadForm')?.reset();
    document.getElementById('patientSearchResults').innerHTML = '';
    selectedPatientForPrescription = null;
    
    const bootstrapModal = new bootstrap.Modal(modal);
    bootstrapModal.show();
}

async function searchPatients() {
    const searchQuery = document.getElementById('patientSearchInput').value.trim();
    const resultsContainer = document.getElementById('patientSearchResults');
    
    if (!searchQuery || searchQuery.length < 3) {
        resultsContainer.innerHTML = '<div class="text-muted small">Enter at least 3 characters to search...</div>';
        return;
    }
    
    resultsContainer.innerHTML = '<div class="spinner-border spinner-border-sm"></div> Searching...';
    
    try {
        // Search in appointments for patients (any practitioner, not just current one)
        const { data: appointmentPatients } = await authHelpers.supabaseClient
            .from('appointments')
            .select('patient_name, patient_email, patient_phone, user_id')
            .ilike('patient_email', `%${searchQuery}%`);
        
        // Also search in prescriptions
        const { data: prescriptionPatients } = await authHelpers.supabaseClient
            .from('prescriptions')
            .select('patient_name, patient_email, user_id')
            .ilike('patient_email', `%${searchQuery}%`);
        
        // Combine results and remove duplicates
        const allPatients = [...(appointmentPatients || []), ...(prescriptionPatients || [])];
        const uniquePatients = Array.from(
            new Map(allPatients.map(item => [item.patient_email || item.user_id, item])).values()
        );
        
        if (uniquePatients.length === 0) {
            // If no results, allow manual entry
            resultsContainer.innerHTML = `
                <div class="alert alert-info py-2 px-3 small mb-2">
                    No existing patient found. You can enter patient details manually:
                </div>
                <div class="border rounded p-3 bg-light">
                    <div class="mb-2">
                        <label class="form-label small mb-1">Patient Name:</label>
                        <input type="text" class="form-control form-control-sm" id="manualPatientName" placeholder="Enter patient name">
                    </div>
                    <div class="mb-2">
                        <label class="form-label small mb-1">Patient Email:</label>
                        <input type="email" class="form-control form-control-sm" id="manualPatientEmail" value="${searchQuery}" placeholder="patient@email.com">
                    </div>
                    <button class="btn btn-sm btn-primary mt-2" onclick="selectManualPatient()">Use This Patient</button>
                </div>
            `;
            return;
        }
        
        resultsContainer.innerHTML = uniquePatients.map(patient => `
            <div class="border rounded p-2 mb-2 patient-search-result" onclick="selectPatient('${patient.user_id || ''}', '${patient.patient_name || 'Unknown'}', '${patient.patient_email || searchQuery}')" style="cursor: pointer;">
                <strong>${patient.patient_name || 'Unknown'}</strong>
                <div class="small text-muted">${patient.patient_email || searchQuery}</div>
                ${patient.patient_phone ? `<div class="small text-muted">${patient.patient_phone}</div>` : ''}
            </div>
        `).join('');
        
    } catch (error) {
        console.error('Patient search error:', error);
        resultsContainer.innerHTML = `<div class="text-danger small">Error: ${error.message}</div>`;
    }
}

function selectPatient(userId, patientName, patientEmail) {
    selectedPatientForPrescription = { userId, patientName, patientEmail };
    
    // Highlight selected patient
    document.querySelectorAll('.patient-search-result').forEach(el => {
        el.classList.remove('bg-light', 'border-primary');
    });
    event.target.closest('.patient-search-result')?.classList.add('bg-light', 'border-primary');
    
    // Show selection feedback
    document.getElementById('selectedPatientInfo').innerHTML = `
        <div class="alert alert-info py-2 px-3 small mb-0">
            ✓ Selected: <strong>${patientName}</strong> (${patientEmail})
        </div>
    `;
}

function selectManualPatient() {
    const patientName = document.getElementById('manualPatientName').value.trim();
    const patientEmail = document.getElementById('manualPatientEmail').value.trim();
    
    if (!patientName || !patientEmail) {
        alert('Please enter both patient name and email.');
        return;
    }
    
    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(patientEmail)) {
        alert('Please enter a valid email address.');
        return;
    }
    
    selectedPatientForPrescription = { 
        userId: null, // Will be created if patient registers later
        patientName, 
        patientEmail 
    };
    
    // Show selection feedback
    document.getElementById('selectedPatientInfo').innerHTML = `
        <div class="alert alert-success py-2 px-3 small mb-0">
            ✓ Manual Entry: <strong>${patientName}</strong> (${patientEmail})
        </div>
    `;
    
    // Clear search results
    document.getElementById('patientSearchResults').innerHTML = '';
}

async function uploadPrescriptionForPatient() {
    if (!selectedPatientForPrescription) {
        alert('Please select a patient first.');
        return;
    }
    
    const form = document.getElementById('prescriptionUploadForm');
    const fileInput = document.getElementById('prescriptionFile');
    const doctorName = document.getElementById('rxDoctorName').value.trim();
    const prescriptionDate = document.getElementById('rxDate').value;
    const expiryDate = document.getElementById('rxExpiry').value;
    const refills = parseInt(document.getElementById('rxRefills').value) || 0;
    const notes = document.getElementById('rxNotes').value.trim();
    
    if (!fileInput.files[0]) {
        alert('Please select a prescription file.');
        return;
    }
    
    if (!doctorName || !prescriptionDate) {
        alert('Please fill in all required fields (Doctor Name and Prescription Date).');
        return;
    }
    
    const file = fileInput.files[0];
    const reader = new FileReader();
    
    reader.onload = async function(e) {
        const fileData = e.target.result;
        
        const prescriptionData = {
            id: 'RX-' + Date.now(),
            file_name: file.name,
            file_data: fileData,
            doctor_name: doctorName,
            prescription_date: prescriptionDate,
            prescription_expiry: expiryDate || null,
            refills_allowed: refills,
            notes: notes,
            status: 'Verified', // Practitioner-uploaded prescriptions are auto-verified
            verified: true,
            user_id: selectedPatientForPrescription.userId,
            practitioner_id: practitionerRecord.id,
            uploaded_by_user_id: currentUserId,
            patient_name: selectedPatientForPrescription.patientName,
            patient_email: selectedPatientForPrescription.patientEmail,
            upload_date: new Date().toISOString()
        };
        
        try {
            const { error } = await authHelpers.supabaseClient
                .from('prescriptions')
                .insert(prescriptionData);
            
            if (error) throw error;
            
            alert('✅ Prescription uploaded successfully!');
            bootstrap.Modal.getInstance(document.getElementById('uploadPrescriptionModal')).hide();
            document.getElementById('uploadPrescriptionForm').reset();
            loadPrescriptions(currentUserId); // Reload prescriptions list
            
        } catch (error) {
            console.error('Upload prescription error:', error);
            alert('Error uploading prescription: ' + error.message);
        }
    };
    
    reader.readAsDataURL(file);
}

window.openAIFeature = openAIFeature;

// =====================================================
// VOICE MEDICAL SCRIBE HISTORY
// =====================================================

async function loadVoiceScribeHistory(limit = null) {
    const container = document.getElementById('voiceScribeHistoryList');
    
    if (!currentUserId) {
        container.innerHTML = '<div class="text-muted">Please log in to view voice scribe history.</div>';
        return;
    }
    
    try {
        container.innerHTML = '<div class="text-muted"><div class="spinner-border spinner-border-sm me-2"></div>Loading...</div>';
        
        let query = authHelpers.supabaseClient
            .from('voice_scribe_sessions')
            .select('*')
            .eq('user_id', currentUserId)
            .order('created_at', { ascending: false });
        
        // Apply limit if showing latest only
        if (limit || viewState.voiceScribe === 'latest') {
            query = query.limit(limit || 1);
        }
        
        const { data, error } = await query;
        
        if (error) throw error;
        
        if (!data || data.length === 0) {
            container.innerHTML = '<div class="text-muted">No voice scribe sessions yet. Use the Voice Medical Scribe feature on the practitioners page to create clinical documentation.</div>';
            return;
        }
        
        container.innerHTML = data.map(session => {
            const date = new Date(session.created_at).toLocaleString('en-US', {
                year: 'numeric',
                month: 'short',
                day: 'numeric',
                hour: '2-digit',
                minute: '2-digit'
            });
            
            const transcriptPreview = session.transcription_text 
                ? (session.transcription_text.substring(0, 100) + (session.transcription_text.length > 100 ? '...' : ''))
                : 'No transcription';
            
            const notesPreview = session.clinical_notes 
                ? (session.clinical_notes.substring(0, 150) + (session.clinical_notes.length > 150 ? '...' : ''))
                : 'No clinical notes generated';
            
            const hasPDF = session.pdf_base64 && session.pdf_base64.length > 0;
            
            return `
                <div class="card mb-3 border-success">
                    <div class="card-body">
                        <div class="d-flex justify-content-between align-items-start mb-2">
                            <div>
                                <h6 class="card-title mb-1">
                                    <i class="fas fa-microphone text-success me-2"></i>
                                    Clinical Documentation Session
                                </h6>
                                <small class="text-muted">
                                    <i class="fas fa-clock me-1"></i>${date}
                                    ${session.word_count ? ` • ${session.word_count} words` : ''}
                                </small>
                            </div>
                            ${hasPDF ? `
                                <button class="btn btn-sm btn-outline-success" onclick="viewScribePDF('${session.id}')">
                                    <i class="fas fa-file-pdf me-1"></i>View PDF
                                </button>
                            ` : ''}
                        </div>
                        
                        <div class="mb-2">
                            <strong class="small">Transcription:</strong>
                            <p class="small text-muted mb-1">${transcriptPreview}</p>
                        </div>
                        
                        ${session.clinical_notes ? `
                            <div class="mb-2">
                                <strong class="small">AI-Generated Notes:</strong>
                                <p class="small text-muted mb-1" style="white-space: pre-wrap;">${notesPreview}</p>
                            </div>
                        ` : ''}
                        
                        <div class="btn-group btn-group-sm" role="group">
                            <button class="btn btn-outline-primary" onclick="viewFullScribeSession('${session.id}')">
                                <i class="fas fa-eye me-1"></i>View Full
                            </button>
                            ${hasPDF ? `
                                <button class="btn btn-outline-success" onclick="downloadScribePDF('${session.id}', '${session.pdf_filename || 'clinical-notes.pdf'}')">
                                    <i class="fas fa-download me-1"></i>Download PDF
                                </button>
                            ` : ''}
                            <button class="btn btn-outline-danger" onclick="deleteScribeSession('${session.id}')">
                                <i class="fas fa-trash me-1"></i>Delete
                            </button>
                        </div>
                    </div>
                </div>
            `;
        }).join('');
        
    } catch (error) {
        console.error('Error loading voice scribe history:', error);
        container.innerHTML = `<div class="alert alert-danger">Error loading history: ${error.message}</div>`;
    }
}

async function viewFullScribeSession(sessionId) {
    try {
        const { data, error } = await authHelpers.supabaseClient
            .from('voice_scribe_sessions')
            .select('*')
            .eq('id', sessionId)
            .single();
        
        if (error) throw error;
        
        const date = new Date(data.created_at).toLocaleString('en-US', {
            year: 'numeric',
            month: 'long',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });
        
        const modalHTML = `
            <div class="modal fade" id="viewScribeSessionModal" tabindex="-1">
                <div class="modal-dialog modal-xl">
                    <div class="modal-content">
                        <div class="modal-header bg-success text-white">
                            <h5 class="modal-title">
                                <i class="fas fa-microphone me-2"></i>
                                Clinical Documentation - ${date}
                            </h5>
                            <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
                        </div>
                        <div class="modal-body">
                            <div class="row">
                                <div class="col-md-6">
                                    <h6><i class="fas fa-file-alt me-2"></i>Transcription</h6>
                                    <div class="p-3 mb-3 border rounded" style="max-height: 400px; overflow-y: auto; background: #f8f9fa;">
                                        ${data.transcription_text || '<em class="text-muted">No transcription</em>'}
                                    </div>
                                </div>
                                <div class="col-md-6">
                                    <h6><i class="fas fa-notes-medical me-2"></i>AI-Generated Clinical Notes</h6>
                                    <div class="p-3 mb-3 border rounded" style="max-height: 400px; overflow-y: auto; background: #f8f9fa; white-space: pre-wrap;">
                                        ${data.clinical_notes || '<em class="text-muted">No clinical notes</em>'}
                                    </div>
                                </div>
                            </div>
                            <div class="row mt-3">
                                <div class="col-12">
                                    <small class="text-muted">
                                        Session ID: ${data.session_id} | 
                                        Words: ${data.word_count || 'N/A'} | 
                                        Language: ${data.language || 'N/A'}
                                    </small>
                                </div>
                            </div>
                        </div>
                        <div class="modal-footer">
                            ${data.pdf_base64 ? `
                                <button class="btn btn-success" onclick="downloadScribePDF('${data.id}', '${data.pdf_filename || 'clinical-notes.pdf'}')">
                                    <i class="fas fa-file-pdf me-2"></i>Download PDF
                                </button>
                            ` : ''}
                            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Close</button>
                        </div>
                    </div>
                </div>
            </div>
        `;
        
        // Remove existing modal if present
        const existingModal = document.getElementById('viewScribeSessionModal');
        if (existingModal) existingModal.remove();
        
        // Add modal to page
        document.body.insertAdjacentHTML('beforeend', modalHTML);
        
        // Show modal
        const modal = new bootstrap.Modal(document.getElementById('viewScribeSessionModal'));
        modal.show();
        
        // Clean up when modal is closed
        document.getElementById('viewScribeSessionModal').addEventListener('hidden.bs.modal', function() {
            this.remove();
        });
        
    } catch (error) {
        console.error('Error viewing session:', error);
        alert('Error loading session: ' + error.message);
    }
}

async function viewScribePDF(sessionId) {
    try {
        const { data, error } = await authHelpers.supabaseClient
            .from('voice_scribe_sessions')
            .select('pdf_base64, pdf_filename')
            .eq('id', sessionId)
            .single();
        
        if (error) throw error;
        
        if (!data.pdf_base64) {
            alert('No PDF available for this session');
            return;
        }
        
        // Convert base64 to blob to avoid browser blocking
        const byteCharacters = atob(data.pdf_base64);
        const byteNumbers = new Array(byteCharacters.length);
        for (let i = 0; i < byteCharacters.length; i++) {
            byteNumbers[i] = byteCharacters.charCodeAt(i);
        }
        const byteArray = new Uint8Array(byteNumbers);
        const blob = new Blob([byteArray], { type: 'application/pdf' });
        
        // Create object URL and open in new tab
        const blobUrl = URL.createObjectURL(blob);
        const newWindow = window.open(blobUrl, '_blank');
        
        // Clean up the object URL after a delay
        if (newWindow) {
            setTimeout(() => URL.revokeObjectURL(blobUrl), 100);
        } else {
            // If popup was blocked, offer download instead
            URL.revokeObjectURL(blobUrl);
            if (confirm('Popup blocked. Would you like to download the PDF instead?')) {
                downloadScribePDF(sessionId, data.pdf_filename);
            }
        }
        
    } catch (error) {
        console.error('Error viewing PDF:', error);
        alert('Error viewing PDF: ' + error.message);
    }
}

async function downloadScribePDF(sessionId, filename) {
    try {
        const { data, error } = await authHelpers.supabaseClient
            .from('voice_scribe_sessions')
            .select('pdf_base64, pdf_filename')
            .eq('id', sessionId)
            .single();
        
        if (error) throw error;
        
        if (!data.pdf_base64) {
            alert('No PDF available for this session');
            return;
        }
        
        // Create download link
        const pdfDataUrl = 'data:application/pdf;base64,' + data.pdf_base64;
        const link = document.createElement('a');
        link.href = pdfDataUrl;
        link.download = filename || data.pdf_filename || 'clinical-notes.pdf';
        link.click();
        
    } catch (error) {
        console.error('Error downloading PDF:', error);
        alert('Error downloading PDF: ' + error.message);
    }
}

async function deleteScribeSession(sessionId) {
    if (!confirm('Are you sure you want to delete this voice scribe session? This action cannot be undone.')) {
        return;
    }
    
    try {
        const { error } = await authHelpers.supabaseClient
            .from('voice_scribe_sessions')
            .delete()
            .eq('id', sessionId);
        
        if (error) throw error;
        
        alert('✅ Session deleted successfully');
        loadVoiceScribeHistory(); // Reload history
        
    } catch (error) {
        console.error('Error deleting session:', error);
        alert('Error deleting session: ' + error.message);
    }
}

// Make functions globally accessible
window.loadVoiceScribeHistory = loadVoiceScribeHistory;
window.viewFullScribeSession = viewFullScribeSession;
window.viewScribePDF = viewScribePDF;
window.downloadScribePDF = downloadScribePDF;
window.deleteScribeSession = deleteScribeSession;

// =====================================================
// VIEW TOGGLE FUNCTIONS
// =====================================================

function toggleAppointmentsView(view) {
    viewState.appointments = view;
    
    // Update button states
    document.getElementById('appointmentsLatestBtn').classList.toggle('active', view === 'latest');
    document.getElementById('appointmentsAllBtn').classList.toggle('active', view === 'all');
    
    // Reload appointments with new limit
    loadAppointments(currentUserId);
}

function togglePrescriptionsView(view) {
    viewState.prescriptions = view;
    
    // Update button states
    document.getElementById('prescriptionsLatestBtn').classList.toggle('active', view === 'latest');
    document.getElementById('prescriptionsAllBtn').classList.toggle('active', view === 'all');
    
    // Reload prescriptions with new limit
    loadPrescriptions(currentUserId);
}

function toggleDeliveriesView(view) {
    viewState.deliveries = view;
    
    // Update button states
    document.getElementById('deliveriesLatestBtn').classList.toggle('active', view === 'latest');
    document.getElementById('deliveriesAllBtn').classList.toggle('active', view === 'all');
    
    // Reload deliveries with new limit
    loadDeliveries(currentUserId);
}

function toggleVoiceScribeView(view) {
    viewState.voiceScribe = view;
    
    // Update button states
    document.getElementById('voiceScribeLatestBtn').classList.toggle('active', view === 'latest');
    document.getElementById('voiceScribeAllBtn').classList.toggle('active', view === 'all');
    
    // Reload voice scribe history with new limit
    loadVoiceScribeHistory();
}

// Make toggle functions globally accessible
window.toggleAppointmentsView = toggleAppointmentsView;
window.togglePrescriptionsView = togglePrescriptionsView;
window.toggleDeliveriesView = toggleDeliveriesView;
window.toggleVoiceScribeView = toggleVoiceScribeView;
