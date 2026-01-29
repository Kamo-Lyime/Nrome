/**
 * APPOINTMENT BOOKING MODULE
 * Handles the complete appointment booking workflow with Paystack payments
 */

class AppointmentBooking {
    constructor() {
        this.supabase = window.supabase;
        this.paystack = new PaystackIntegration();
        this.currentUser = null;
        this.selectedPractitioner = null;
        this.selectedSlot = null;
    }

    /**
     * Initialize the booking system
     */
    async init() {
        try {
            // Get current user
            const { data: { user } } = await this.supabase.auth.getUser();
            this.currentUser = user;

            if (!this.currentUser) {
                console.warn('User not authenticated');
                return false;
            }

            console.log('✅ Appointment Booking initialized');
            return true;
        } catch (error) {
            console.error('Initialization error:', error);
            return false;
        }
    }

    /**
     * STEP 1: Patient selects practitioner and time slot
     */
    selectSlot(practitioner, date, time) {
        this.selectedPractitioner = practitioner;
        this.selectedSlot = {
            date: date,
            time: time
        };

        console.log('Slot selected:', {
            practitioner: practitioner.name,
            date: date,
            time: time
        });

        return true;
    }

    /**
     * STEP 2: Create appointment with PENDING_PAYMENT status
     * This is called BEFORE payment
     */
    async createPendingAppointment(appointmentDetails) {
        try {
            const {
                practitionerId,
                practitionerName,
                patientName,
                patientPhone,
                patientEmail,
                appointmentDate,
                appointmentTime,
                reasonForVisit = '',
                appointmentType = 'consultation'
            } = appointmentDetails;

            // Generate unique booking ID and payment reference
            const bookingId = this.generateBookingId();
            const paymentReference = this.paystack.generateReference('APT');
            const confirmationDeadline = this.paystack.getConfirmationDeadline();

            // Calculate payment split
            const amount = 500; // R500.00
            const split = this.paystack.calculateSplit(amount);

            // Create appointment in database with PENDING_PAYMENT status
            const { data: appointment, error } = await this.supabase
                .from('appointments')
                .insert([
                    {
                        booking_id: bookingId,
                        user_id: this.currentUser.id,
                        practitioner_id: practitionerId,
                        practitioner_name: practitionerName,
                        patient_name: patientName,
                        patient_phone: patientPhone,
                        patient_email: patientEmail,
                        appointment_date: appointmentDate,
                        appointment_time: appointmentTime,
                        appointment_type: appointmentType,
                        reason_for_visit: reasonForVisit,
                        status: 'PENDING_PAYMENT',
                        payment_status: 'pending',
                        payment_reference: paymentReference,
                        amount_paid: amount,
                        currency: 'ZAR',
                        platform_fee: split.platformFee,
                        practitioner_amount: split.practitionerAmount,
                        confirmation_deadline: confirmationDeadline,
                        cancellation_policy: '24h_full_refund'
                    }
                ])
                .select()
                .single();

            if (error) {
                console.error('Appointment creation error:', error);
                return { success: false, error: error.message };
            }

            // Log the creation
            await this.logAppointmentAction(appointment.id, 'appointment_created', 'patient');

            console.log('✅ Appointment created with PENDING_PAYMENT status:', appointment);

            return {
                success: true,
                appointment: appointment,
                paymentReference: paymentReference,
                amount: amount,
                split: split
            };

        } catch (error) {
            console.error('Error creating pending appointment:', error);
            return { success: false, error: error.message };
        }
    }

    /**
     * STEP 3: Initiate Paystack payment
     * Opens payment modal after appointment is created
     */
    async initiatePayment(appointment) {
        return new Promise((resolve, reject) => {
            const paymentData = {
                id: appointment.id,
                amount: appointment.amount_paid * 100, // Convert to kobo
                email: appointment.patient_email || this.currentUser.email,
                reference: appointment.payment_reference,
                patient_name: appointment.patient_name,
                practitioner_id: appointment.practitioner_id,
                appointment_date: appointment.appointment_date,
                appointment_time: appointment.appointment_time
            };

            this.paystack.initiatePayment(
                paymentData,
                async (response) => {
                    // Payment successful callback
                    console.log('Payment successful:', response);
                    
                    // Update appointment to PENDING_CONFIRMATION
                    const updateResult = await this.updateAppointmentAfterPayment(
                        appointment.id,
                        response.reference
                    );
                    
                    resolve({
                        success: true,
                        response: response,
                        appointment: updateResult.appointment
                    });
                },
                () => {
                    // Payment window closed
                    console.log('Payment window closed by user');
                    reject({
                        success: false,
                        error: 'Payment cancelled by user'
                    });
                }
            );
        });
    }

    /**
     * STEP 4: Update appointment after successful payment
     * Changes status from PENDING_PAYMENT to PENDING_CONFIRMATION
     */
    async updateAppointmentAfterPayment(appointmentId, paystackReference) {
        try {
            // Verify payment with Paystack first
            const verification = await this.paystack.verifyPayment(paystackReference);

            if (!verification.success) {
                console.error('Payment verification failed:', verification);
                
                // Update to PAYMENT_FAILED
                await this.supabase
                    .from('appointments')
                    .update({
                        status: 'PAYMENT_FAILED',
                        payment_status: 'failed'
                    })
                    .eq('id', appointmentId);

                return {
                    success: false,
                    error: 'Payment verification failed'
                };
            }

            // Update appointment status to PENDING_CONFIRMATION
            const { data: appointment, error } = await this.supabase
                .from('appointments')
                .update({
                    status: 'PENDING_CONFIRMATION',
                    payment_status: 'success',
                    payment_metadata: verification.data
                })
                .eq('id', appointmentId)
                .select()
                .single();

            if (error) {
                console.error('Update error:', error);
                return { success: false, error: error.message };
            }

            // Record transaction
            await this.recordTransaction(appointment, verification.data, 'payment');

            // Log the payment success
            await this.logAppointmentAction(appointmentId, 'payment_successful', 'system');

            // Notify practitioner
            await this.notifyPractitioner(appointment);

            console.log('✅ Appointment updated to PENDING_CONFIRMATION');

            return {
                success: true,
                appointment: appointment
            };

        } catch (error) {
            console.error('Error updating appointment after payment:', error);
            return { success: false, error: error.message };
        }
    }

    /**
     * STEP 5: Practitioner confirms appointment
     * Changes status from PENDING_CONFIRMATION to CONFIRMED
     */
    async confirmAppointment(appointmentId, practitionerNotes = '') {
        try {
            const { data: appointment, error } = await this.supabase
                .from('appointments')
                .update({
                    status: 'CONFIRMED',
                    confirmed_at: new Date().toISOString(),
                    practitioner_notes: practitionerNotes
                })
                .eq('id', appointmentId)
                .eq('status', 'PENDING_CONFIRMATION') // Only confirm if in correct state
                .select()
                .single();

            if (error) {
                console.error('Confirmation error:', error);
                return { success: false, error: error.message };
            }

            // Log the confirmation
            await this.logAppointmentAction(appointmentId, 'practitioner_confirmed', 'practitioner');

            // Notify patient
            await this.notifyPatient(appointment, 'confirmed');

            console.log('✅ Appointment confirmed by practitioner');

            return {
                success: true,
                appointment: appointment
            };

        } catch (error) {
            console.error('Error confirming appointment:', error);
            return { success: false, error: error.message };
        }
    }

    /**
     * STEP 6: Mark appointment as completed
     * Called after appointment occurs
     */
    async completeAppointment(appointmentId) {
        try {
            const { data: appointment, error } = await this.supabase
                .from('appointments')
                .update({
                    status: 'COMPLETED'
                })
                .eq('id', appointmentId)
                .eq('status', 'CONFIRMED')
                .select()
                .single();

            if (error) {
                console.error('Completion error:', error);
                return { success: false, error: error.message };
            }

            // Log completion
            await this.logAppointmentAction(appointmentId, 'appointment_completed', 'system');

            console.log('✅ Appointment marked as completed');

            return {
                success: true,
                appointment: appointment
            };

        } catch (error) {
            console.error('Error completing appointment:', error);
            return { success: false, error: error.message };
        }
    }

    /**
     * REFUND CASE A: Practitioner does not confirm (timeout)
     * Auto-refund 100%
     */
    async handleUnconfirmedTimeout(appointmentId) {
        try {
            const { data: appointment } = await this.supabase
                .from('appointments')
                .select('*')
                .eq('id', appointmentId)
                .single();

            if (!appointment || appointment.status !== 'PENDING_CONFIRMATION') {
                return { success: false, error: 'Invalid appointment state' };
            }

            // Check if past confirmation deadline
            if (new Date() <= new Date(appointment.confirmation_deadline)) {
                return { success: false, error: 'Confirmation deadline not yet passed' };
            }

            // Initiate full refund
            const refundResult = await this.initiateRefund(
                appointment,
                appointment.amount_paid,
                'Practitioner did not confirm within 24 hours'
            );

            if (!refundResult.success) {
                return refundResult;
            }

            console.log('✅ Unconfirmed appointment refunded');

            return {
                success: true,
                appointment: refundResult.appointment
            };

        } catch (error) {
            console.error('Error handling unconfirmed timeout:', error);
            return { success: false, error: error.message };
        }
    }

    /**
     * REFUND CASE B: Practitioner explicitly declines
     * 100% refund, no fees kept
     */
    async handlePractitionerDecline(appointmentId, reason = '') {
        try {
            const { data: appointment } = await this.supabase
                .from('appointments')
                .select('*')
                .eq('id', appointmentId)
                .single();

            if (!appointment) {
                return { success: false, error: 'Appointment not found' };
            }

            // Initiate full refund
            const refundResult = await this.initiateRefund(
                appointment,
                appointment.amount_paid,
                `Practitioner declined: ${reason}`
            );

            if (!refundResult.success) {
                return refundResult;
            }

            // Log the decline
            await this.logAppointmentAction(
                appointmentId,
                'practitioner_declined',
                'practitioner',
                { reason: reason }
            );

            console.log('✅ Practitioner decline processed with full refund');

            return {
                success: true,
                appointment: refundResult.appointment
            };

        } catch (error) {
            console.error('Error handling practitioner decline:', error);
            return { success: false, error: error.message };
        }
    }

    /**
     * REFUND CASE C & D: Patient cancels
     * ≥24h before: 100% refund
     * <24h before: No refund (no-show policy applies)
     */
    async handlePatientCancellation(appointmentId, reason = '') {
        try {
            const { data: appointment } = await this.supabase
                .from('appointments')
                .select('*')
                .eq('id', appointmentId)
                .single();

            if (!appointment) {
                return { success: false, error: 'Appointment not found' };
            }

            // Check refund eligibility
            const isEligible = this.paystack.isFullRefundEligible(
                appointment.appointment_date,
                appointment.appointment_time
            );

            if (isEligible) {
                // Full refund
                const refundResult = await this.initiateRefund(
                    appointment,
                    appointment.amount_paid,
                    `Patient cancelled: ${reason}`
                );

                return refundResult;
            } else {
                // No refund - apply no-show policy
                const { data: updated, error } = await this.supabase
                    .from('appointments')
                    .update({
                        status: 'CANCELLED',
                        cancelled_by: 'patient',
                        cancellation_reason: `Late cancellation (<24h): ${reason}`,
                        no_show_fee: appointment.amount_paid
                    })
                    .eq('id', appointmentId)
                    .select()
                    .single();

                if (error) {
                    return { success: false, error: error.message };
                }

                await this.logAppointmentAction(
                    appointmentId,
                    'patient_cancelled_late',
                    'patient',
                    { reason: reason, no_refund: true }
                );

                console.log('⚠️ Late cancellation - no refund policy applied');

                return {
                    success: true,
                    refunded: false,
                    appointment: updated,
                    message: 'Cancellation within 24 hours - no refund per policy'
                };
            }

        } catch (error) {
            console.error('Error handling patient cancellation:', error);
            return { success: false, error: error.message };
        }
    }

    /**
     * REFUND CASE E: Practitioner cancels after confirmation
     * 100% refund + optional goodwill credit
     */
    async handlePractitionerCancellation(appointmentId, reason = '') {
        try {
            const { data: appointment } = await this.supabase
                .from('appointments')
                .select('*')
                .eq('id', appointmentId)
                .single();

            if (!appointment) {
                return { success: false, error: 'Appointment not found' };
            }

            // Full refund regardless of timing
            const refundResult = await this.initiateRefund(
                appointment,
                appointment.amount_paid,
                `Practitioner cancelled: ${reason}`
            );

            if (!refundResult.success) {
                return refundResult;
            }

            // Log practitioner cancellation
            await this.logAppointmentAction(
                appointmentId,
                'practitioner_cancelled',
                'practitioner',
                { reason: reason }
            );

            console.log('✅ Practitioner cancellation processed with full refund');

            return {
                success: true,
                appointment: refundResult.appointment,
                message: 'Full refund issued due to practitioner cancellation'
            };

        } catch (error) {
            console.error('Error handling practitioner cancellation:', error);
            return { success: false, error: error.message };
        }
    }

    /**
     * Handle no-show
     */
    async handleNoShow(appointmentId) {
        try {
            const { data: appointment, error } = await this.supabase
                .from('appointments')
                .update({
                    status: 'NO_SHOW',
                    no_show_checked: true,
                    no_show_fee: appointment.amount_paid // Full amount as no-show fee
                })
                .eq('id', appointmentId)
                .eq('status', 'CONFIRMED')
                .select()
                .single();

            if (error) {
                console.error('No-show update error:', error);
                return { success: false, error: error.message };
            }

            // Log no-show
            await this.logAppointmentAction(appointmentId, 'marked_no_show', 'system');

            console.log('⚠️ Appointment marked as NO_SHOW');

            return {
                success: true,
                appointment: appointment
            };

        } catch (error) {
            console.error('Error handling no-show:', error);
            return { success: false, error: error.message };
        }
    }

    /**
     * Core refund function
     */
    async initiateRefund(appointment, amount, reason) {
        try {
            // Call Paystack refund API
            const refundResult = await this.paystack.initiateRefund(
                appointment.payment_reference,
                amount,
                reason
            );

            if (!refundResult.success) {
                console.error('Refund failed:', refundResult);
                return { success: false, error: refundResult.message };
            }

            // Update appointment
            const { data: updated, error } = await this.supabase
                .from('appointments')
                .update({
                    status: 'REFUNDED',
                    payment_status: 'refunded',
                    refund_reference: refundResult.refund_id,
                    refunded_at: new Date().toISOString(),
                    cancellation_reason: reason
                })
                .eq('id', appointment.id)
                .select()
                .single();

            if (error) {
                return { success: false, error: error.message };
            }

            // Record refund transaction
            await this.recordTransaction(appointment, refundResult.data, 'refund');

            // Log refund
            await this.logAppointmentAction(appointment.id, 'refund_processed', 'system', {
                amount: amount,
                reason: reason
            });

            // Notify patient
            await this.notifyPatient(updated, 'refunded');

            return {
                success: true,
                appointment: updated
            };

        } catch (error) {
            console.error('Refund error:', error);
            return { success: false, error: error.message };
        }
    }

    /**
     * Record payment transaction
     */
    async recordTransaction(appointment, paystackData, type) {
        try {
            const { error } = await this.supabase
                .from('payment_transactions')
                .insert([
                    {
                        appointment_id: appointment.id,
                        reference: appointment.payment_reference,
                        paystack_reference: paystackData.reference || paystackData.transaction,
                        transaction_type: type,
                        amount: appointment.amount_paid,
                        currency: appointment.currency,
                        platform_fee: appointment.platform_fee,
                        practitioner_amount: appointment.practitioner_amount,
                        status: 'success',
                        patient_id: appointment.user_id,
                        practitioner_id: appointment.practitioner_id,
                        paystack_response: paystackData,
                        completed_at: new Date().toISOString()
                    }
                ]);

            if (error) {
                console.error('Transaction recording error:', error);
            }

        } catch (error) {
            console.error('Error recording transaction:', error);
        }
    }

    /**
     * Log appointment action
     */
    async logAppointmentAction(appointmentId, action, actor, metadata = {}) {
        try {
            await this.supabase
                .from('appointment_logs')
                .insert([
                    {
                        appointment_id: appointmentId,
                        action: action,
                        actor: actor,
                        actor_user_id: this.currentUser?.id,
                        metadata: metadata
                    }
                ]);
        } catch (error) {
            console.error('Error logging action:', error);
        }
    }

    /**
     * Notify practitioner of new appointment
     */
    async notifyPractitioner(appointment) {
        try {
            await this.supabase
                .from('practitioner_notifications')
                .insert([
                    {
                        practitioner_id: appointment.practitioner_id,
                        appointment_id: appointment.id,
                        notification_type: 'new_appointment',
                        message: `New appointment from ${appointment.patient_name} on ${appointment.appointment_date} at ${appointment.appointment_time}. Please confirm within 24 hours.`
                    }
                ]);

            console.log('✅ Practitioner notified');
        } catch (error) {
            console.error('Error notifying practitioner:', error);
        }
    }

    /**
     * Notify patient
     */
    async notifyPatient(appointment, type) {
        // This would integrate with your notification system
        // For now, just log
        console.log(`📧 Patient notification (${type}):`, appointment.patient_email);
    }

    /**
     * Generate booking ID
     */
    generateBookingId() {
        const timestamp = Date.now();
        const random = Math.floor(Math.random() * 1000);
        return `BK${timestamp}${random}`;
    }

    /**
     * Get user's appointments
     */
    async getUserAppointments() {
        try {
            const { data, error } = await this.supabase
                .from('appointments')
                .select('*, medical_practitioners(*)')
                .eq('user_id', this.currentUser.id)
                .order('created_at', { ascending: false });

            if (error) {
                console.error('Error fetching appointments:', error);
                return { success: false, error: error.message };
            }

            return {
                success: true,
                appointments: data
            };

        } catch (error) {
            console.error('Error getting user appointments:', error);
            return { success: false, error: error.message };
        }
    }

    /**
     * Get practitioner's appointments
     */
    async getPractitionerAppointments(practitionerId) {
        try {
            const { data, error } = await this.supabase
                .from('appointments')
                .select('*')
                .eq('practitioner_id', practitionerId)
                .order('appointment_date', { ascending: true })
                .order('appointment_time', { ascending: true });

            if (error) {
                console.error('Error fetching practitioner appointments:', error);
                return { success: false, error: error.message };
            }

            return {
                success: true,
                appointments: data
            };

        } catch (error) {
            console.error('Error getting practitioner appointments:', error);
            return { success: false, error: error.message };
        }
    }
}

// Export for use
window.AppointmentBooking = AppointmentBooking;
console.log('✅ Appointment Booking Module Loaded');
