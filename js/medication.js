// Supabase Configuration (reuse global client from auth.js to avoid redeclaration)
const LOCAL_SUPABASE_URL = 'https://vpmuooztcqzrrfsvjzwl.supabase.co';
const LOCAL_SUPABASE_ANON_KEY = 'sb_publishable_B-5KuQJXEpxkd167_iraZw_IdvsPJNx';

// Initialize Supabase once (only set if not already defined by auth.js)
let medSupabaseClient = window.supabaseClient;
if (!medSupabaseClient) {
    try {
        medSupabaseClient = supabase.createClient(LOCAL_SUPABASE_URL, LOCAL_SUPABASE_ANON_KEY);
        window.supabaseClient = medSupabaseClient;
        console.log('✅ Supabase initialized successfully');
    } catch (error) {
        console.warn('⚠️ Supabase initialization failed, using localStorage fallback:', error);
        medSupabaseClient = null;
        window.supabaseClient = null;
    }
}

// Alias used throughout this file (does not redeclare the global const)
const medClient = medSupabaseClient;

// Database mode flag
const USE_SUPABASE = !!medClient;

// Track signed-in user
let currentUserId = null;
async function resolveUserId() {
    try {
        if (authHelpers?.getSession) {
            const session = await authHelpers.getSession();
            currentUserId = session?.user?.id || null;
        } else if (medClient) {
            const { data } = await medClient.auth.getSession();
            currentUserId = data?.session?.user?.id || null;
        }
    } catch (err) {
        console.warn('Unable to resolve user id:', err);
        currentUserId = null;
    }
    return currentUserId;
}

console.log('🏥 Medication System Configuration:');
console.log('- Database:', USE_SUPABASE ? '✅ Supabase Connected' : '⚠️ localStorage Fallback');

// Helper function to convert camelCase to snake_case for PostgreSQL
function toSnakeCase(obj) {
    const snakeObj = {};
    for (const key in obj) {
        const snakeKey = key.replace(/([A-Z])/g, '_$1').toLowerCase();
        snakeObj[snakeKey] = obj[key];
    }
    return snakeObj;
}

// Helper function to convert snake_case to camelCase from PostgreSQL
function toCamelCase(obj) {
    const camelObj = {};
    for (const key in obj) {
        const camelKey = key.replace(/_([a-z])/g, (g) => g[1].toUpperCase());
        camelObj[camelKey] = obj[key];
    }
    return camelObj;
}

// Prescription storage (with Supabase or localStorage fallback)
let prescriptions = [];

// Load prescriptions from database
async function loadPrescriptions() {
    const userId = await resolveUserId();

    if (USE_SUPABASE) {
        try {
            let query = medClient
                .from('prescriptions')
                .select('*')
                .order('upload_date', { ascending: false });

            if (userId) {
                query = query.eq('user_id', userId);
            }

            const { data, error } = await query;

            if (error) throw error;
            prescriptions = (data || []).map(toCamelCase);
            console.log('✅ Loaded', prescriptions.length, 'prescriptions from Supabase');
        } catch (error) {
            if (error?.code === '42703') {
                // Column missing (older table) - retry without user filter
                console.warn('user_id column missing on prescriptions; refetching without user filter');
                const { data: fallbackData, error: fallbackError } = await medClient
                    .from('prescriptions')
                    .select('*')
                    .order('upload_date', { ascending: false });
                if (!fallbackError) {
                    prescriptions = (fallbackData || []).map(toCamelCase);
                    console.log('✅ Loaded', prescriptions.length, 'prescriptions from Supabase (no user filter)');
                } else {
                    console.error('Fallback load failed:', fallbackError);
                    prescriptions = JSON.parse(localStorage.getItem('prescriptions') || '[]');
                }
            } else {
                console.error('Error loading prescriptions from Supabase:', error);
                prescriptions = JSON.parse(localStorage.getItem('prescriptions') || '[]');
            }
        }
    } else {
        prescriptions = JSON.parse(localStorage.getItem('prescriptions') || '[]');
    }
}

// Upload prescription
async function uploadPrescription() {
    const fileInput = document.getElementById('prescriptionFile');
    const doctorName = document.getElementById('doctorName').value;
    const prescriptionDate = document.getElementById('prescriptionDate').value;
    const prescriptionExpiry = document.getElementById('prescriptionExpiry').value;
    const refillsAllowed = document.getElementById('refillsAllowed').value;
    const notes = document.getElementById('prescriptionNotes').value;

    if (!fileInput.files.length) {
        alert('Please select at least one prescription file');
        return;
    }

    if (!doctorName || !prescriptionDate) {
        alert('Please fill in doctor name and prescription date');
        return;
    }

    // Process each file
    Array.from(fileInput.files).forEach((file, index) => {
        const reader = new FileReader();
        reader.onload = async function(e) {
            const userId = currentUserId || await resolveUserId();
            const prescription = {
                id: 'RX-' + Date.now() + '-' + index,
                fileName: file.name,
                fileData: e.target.result,
                doctorName: doctorName,
                prescriptionDate: prescriptionDate,
                prescriptionExpiry: prescriptionExpiry || null,
                refillsAllowed: parseInt(refillsAllowed) || 0,
                notes: notes,
                uploadDate: new Date().toISOString(),
                status: 'Pending Verification',
                verified: false,
                userId: userId
            };

            // Save to database
            if (USE_SUPABASE) {
                try {
                        const { error } = await medClient
                        .from('prescriptions')
                        .insert([toSnakeCase(prescription)]);

                    if (error) throw error;

                    prescriptions.push(prescription);
                    console.log('✅ Prescription saved to Supabase');
                } catch (error) {
                    console.error('Error saving to Supabase, using localStorage:', error);
                    prescriptions.push(prescription);
                    localStorage.setItem('prescriptions', JSON.stringify(prescriptions));
                }
            } else {
                prescriptions.push(prescription);
                localStorage.setItem('prescriptions', JSON.stringify(prescriptions));
            }

            // Show success message
            showAlert('success', 'Prescription uploaded successfully! ID: ' + prescription.id);

            // Refresh display
            displayPrescriptions();
            updatePrescriptionDropdown();

            // Clear form
            document.getElementById('prescriptionFile').value = '';
            document.getElementById('doctorName').value = '';
            document.getElementById('prescriptionDate').value = '';
            document.getElementById('prescriptionNotes').value = '';
        };
        reader.readAsDataURL(file);
    });
}

// Display prescriptions
function displayPrescriptions() {
    const listElement = document.getElementById('prescriptionList');

    if (prescriptions.length === 0) {
        listElement.innerHTML = '<div class="alert alert-info"><i class="fas fa-info-circle me-2"></i>No prescriptions uploaded yet. Upload your first prescription above.</div>';
        return;
    }

    listElement.innerHTML = prescriptions.map(function(rx) {
        return '<div class="card mb-3">' +
            '<div class="card-body">' +
                '<div class="row align-items-center">' +
                    '<div class="col-md-2 text-center">' +
                        '<i class="fas fa-file-medical fa-3x text-primary"></i>' +
                    '</div>' +
                    '<div class="col-md-7">' +
                        '<h6 class="mb-1"><strong>Prescription ID:</strong> ' + rx.id + '</h6>' +
                        '<p class="mb-1"><strong>Doctor:</strong> ' + rx.doctorName + '</p>' +
                        '<p class="mb-1"><strong>Date:</strong> ' + new Date(rx.prescriptionDate).toLocaleDateString() + '</p>' +
                        '<p class="mb-1"><strong>File:</strong> ' + rx.fileName + '</p>' +
                        (rx.notes ? '<p class="mb-1"><strong>Notes:</strong> ' + rx.notes + '</p>' : '') +
                        '<p class="mb-0">' +
                            '<span class="badge ' + (rx.verified ? 'bg-success' : 'bg-warning') + '">' +
                                '<i class="fas ' + (rx.verified ? 'fa-check-circle' : 'fa-clock') + ' me-1"></i>' +
                                rx.status +
                            '</span>' +
                        '</p>' +
                    '</div>' +
                    '<div class="col-md-3 text-end">' +
                        '<button class="btn btn-sm btn-info mb-2" onclick="viewPrescription(\'' + rx.id + '\')">' +
                            '<i class="fas fa-eye me-1"></i>View' +
                        '</button>' +
                        '<button class="btn btn-sm btn-danger" onclick="deletePrescription(\'' + rx.id + '\')">' +
                            '<i class="fas fa-trash me-1"></i>Delete' +
                        '</button>' +
                    '</div>' +
                '</div>' +
            '</div>' +
        '</div>';
    }).join('');
}

// Update prescription dropdown
function updatePrescriptionDropdown() {
    const dropdown = document.getElementById('selectedPrescription');
    dropdown.innerHTML = '<option value="">-- No prescription selected --</option>' +
        prescriptions.map(function(rx) {
            return '<option value="' + rx.id + '">' + rx.id + ' - Dr. ' + rx.doctorName + ' (' + new Date(rx.prescriptionDate).toLocaleDateString() + ')</option>';
        }).join('');
}

// View prescription
function viewPrescription(id) {
    const rx = prescriptions.find(p => p.id === id);
    if (rx) {
        // Open prescription in new window
        const win = window.open('', '_blank');
        const html = '<html><head><title>Prescription ' + rx.id + '</title>' +
            '<style>body { font-family: Arial, sans-serif; padding: 20px; } img { max-width: 100%; height: auto; }</style>' +
            '</head><body>' +
            '<h2>Prescription Details</h2>' +
            '<p><strong>ID:</strong> ' + rx.id + '</p>' +
            '<p><strong>Doctor:</strong> ' + rx.doctorName + '</p>' +
            '<p><strong>Date:</strong> ' + new Date(rx.prescriptionDate).toLocaleDateString() + '</p>' +
            '<p><strong>Status:</strong> ' + rx.status + '</p>' +
            (rx.notes ? '<p><strong>Notes:</strong> ' + rx.notes + '</p>' : '') +
            '<hr><h3>Prescription Image/Document</h3>' +
            (rx.fileData.startsWith('data:application/pdf')
                ? '<embed src="' + rx.fileData + '" width="100%" height="400px" type="application/pdf">'
                : '<img src="' + rx.fileData + '" alt="Prescription">') +
            '</body></html>';
        win.document.write(html);
    }
}

// Delete prescription
async function deletePrescription(id) {
    if (confirm('Are you sure you want to delete this prescription?')) {
        // Delete from database
        if (USE_SUPABASE) {
            try {
                const { error } = await medClient
                    .from('prescriptions')
                    .delete()
                    .eq('id', id);

                if (error) throw error;
                console.log('✅ Prescription deleted from Supabase');
            } catch (error) {
                console.error('Error deleting from Supabase:', error);
            }
        }

        prescriptions = prescriptions.filter(p => p.id !== id);
        localStorage.setItem('prescriptions', JSON.stringify(prescriptions));
        displayPrescriptions();
        updatePrescriptionDropdown();
        showAlert('info', 'Prescription deleted successfully');
    }
}

// Show alert
function showAlert(type, message) {
    const alertDiv = document.createElement('div');
    alertDiv.className = 'alert alert-' + type + ' alert-dismissible fade show position-fixed';
    alertDiv.style.top = '20px';
    alertDiv.style.right = '20px';
    alertDiv.style.zIndex = '9999';
    alertDiv.style.maxWidth = '400px';
    alertDiv.innerHTML = message + '<button type="button" class="btn-close" data-bs-dismiss="alert"></button>';
    document.body.appendChild(alertDiv);
    setTimeout(function() { alertDiv.remove(); }, type === 'success' ? 8000 : 5000);
}

// Initialize on page load
document.addEventListener('DOMContentLoaded', async function() {
    await loadPrescriptions();
    displayPrescriptions();
    updatePrescriptionDropdown();
});

// Make functions globally accessible
window.uploadPrescription = uploadPrescription;
window.viewPrescription = viewPrescription;
window.deletePrescription = deletePrescription;

document.getElementById('deliveryForm').addEventListener('submit', async function(e) {
    e.preventDefault();

    const userId = currentUserId || await resolveUserId();
    const selectedPrescriptionId = document.getElementById('selectedPrescription').value;

    const medications = Array.from(document.querySelectorAll('#medicationList li')).map(li => ({
        name: li.querySelector('.medication-name')?.value || li.querySelector('input')?.value || '',
        dosage: li.querySelector('.medication-dosage')?.value || '',
        quantity: li.querySelector('.medication-quantity')?.value || '1'
    }));

    const formData = {
        // Patient Information
        patientName: document.getElementById('patientName').value,
        patientAge: document.getElementById('patientAge').value,
        allergies: document.getElementById('allergies').value,
        currentMedications: document.getElementById('currentMedications').value,
        medicalConditions: document.getElementById('medicalConditions').value,

        // Medication Details
        medications: medications,

        // Delivery Information
        deliveryDate: document.getElementById('deliveryDate').value,
        deliveryTime: document.getElementById('deliveryTime').value,
        deliveryAddress: document.getElementById('deliveryAddress').value,

        // Contact Information
        phoneNumber: document.getElementById('phoneNumber').value,
        emergencyContact: document.getElementById('emergencyContact').value,
        email: document.getElementById('userEmail').value,

        // Payment & Insurance
        insuranceProvider: document.getElementById('insuranceProvider').value,
        insuranceNumber: document.getElementById('insuranceNumber').value,
        paymentMethod: document.getElementById('paymentMethod').value,

        // Additional Information
        additionalComments: document.getElementById('additionalComments').value,
        prescriptionId: selectedPrescriptionId || null,

        // Order Metadata
        orderId: 'ORD-' + Date.now(),
        orderDate: new Date().toISOString(),
        status: 'Pending Verification',
        verified: false,
        userId: userId
    };

    try {
        // Save order to database
        if (USE_SUPABASE) {
            try {
                const { error } = await medClient
                    .from('medication_orders')
                    .insert([toSnakeCase(formData)]);

                if (error) throw error;
                console.log('✅ Order saved to Supabase');
            } catch (error) {
                console.error('Error saving to Supabase, using localStorage:', error);
                const orders = JSON.parse(localStorage.getItem('medicationOrders') || '[]');
                orders.push(formData);
                localStorage.setItem('medicationOrders', JSON.stringify(orders));
            }
        } else {
            const orders = JSON.parse(localStorage.getItem('medicationOrders') || '[]');
            orders.push(formData);
            localStorage.setItem('medicationOrders', JSON.stringify(orders));
        }

        // Show success with order details
        showAlert('success',
            '<strong>Order Submitted Successfully!</strong><br>' +
            'Order ID: ' + formData.orderId + '<br>' +
            (formData.prescriptionId ? 'Prescription ID: ' + formData.prescriptionId + '<br>' : '') +
            'Status: Pending Pharmacist Verification<br>' +
            '<small>Track status in your dashboard.</small>'
        );

        this.reset();
        document.getElementById('selectedPrescription').value = '';

        /* Original API call - uncomment when backend is ready
        const response = await fetch('http://localhost:3000/api/orders', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(formData)
        });

        if (!response.ok) {
            throw new Error('Error submitting form');
        }

        const result = await response.json();
        document.getElementById('successAlert').classList.remove('d-none');
                        const { error } = await medClient
        this.reset();
        */
    } catch (error) {
        console.error('Error:', error);
        showAlert('danger', 'Error submitting form. Please try again.');
    }
});

document.getElementById('addMedication').addEventListener('click', function() {
    const medicationList = document.getElementById('medicationList');
    const newItem = document.createElement('li');
    newItem.className = 'list-group-item';
    newItem.innerHTML =
        '<div class="row">' +
            '<div class="col-md-5">' +
                '<input type="text" class="form-control medication-name" placeholder="Medication name" required>' +
            '</div>' +
            '<div class="col-md-3">' +
                '<input type="text" class="form-control medication-dosage" placeholder="Dosage (e.g., 500mg)">' +
            '</div>' +
            '<div class="col-md-3">' +
                '<input type="number" class="form-control medication-quantity" placeholder="Quantity" min="1" value="1">' +
            '</div>' +
            '<div class="col-md-1">' +
                '<button type="button" class="btn btn-danger btn-sm remove-med"><i class="fas fa-times"></i></button>' +
            '</div>' +
        '</div>';
    medicationList.appendChild(newItem);

    // Add remove functionality
    newItem.querySelector('.remove-med').addEventListener('click', function() {
        newItem.remove();
    });
});
