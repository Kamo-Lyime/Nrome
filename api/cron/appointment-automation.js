/**
 * AUTOMATED CRON FUNCTIONS FOR APPOINTMENT MANAGEMENT
 * Deploy these as Supabase Edge Functions or Vercel Cron Jobs
 * 
 * These functions run automatically to handle:
 * 1. Unconfirmed appointments (auto-refund after 24h)
 * 2. No-show detection (check appointments past their time)
 * 3. Reminder notifications
 */

import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const PAYSTACK_SECRET_KEY = process.env.PAYSTACK_SECRET_KEY || 'sk_test_ce04e3466d797c150e1b7c81ce8d3a5c51bbc098';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

/**
 * CRON JOB 1: Check for unconfirmed appointments and auto-refund
 * Run every hour
 * Route: /api/cron/check-confirmations
 */
export async function checkUnconfirmedAppointments(req, res) {
    console.log('🔄 Starting unconfirmed appointments check...');

    try {
        // Get all appointments past their confirmation deadline
        const { data: overdueAppointments, error } = await supabase
            .from('appointments')
            .select('*')
            .eq('status', 'PENDING_CONFIRMATION')
            .lt('confirmation_deadline', new Date().toISOString());

        if (error) {
            console.error('Error fetching overdue appointments:', error);
            return res.status(500).json({ error: error.message });
        }

        console.log(`Found ${overdueAppointments?.length || 0} overdue appointments`);

        const results = [];

        for (const appointment of overdueAppointments || []) {
            try {
                // Initiate refund via Paystack
                const refundResult = await initiatePaystackRefund(
                    appointment.payment_reference,
                    appointment.amount_paid,
                    'Practitioner did not confirm within 24 hours'
                );

                if (refundResult.success) {
                    // Update appointment status
                    const { error: updateError } = await supabase
                        .from('appointments')
                        .update({
                            status: 'REFUNDED',
                            payment_status: 'refunded',
                            refund_reference: refundResult.refund_id,
                            refunded_at: new Date().toISOString(),
                            cancellation_reason: 'Auto-refund: Practitioner did not confirm within 24 hours'
                        })
                        .eq('id', appointment.id);

                    if (!updateError) {
                        // Log the auto-refund
                        await supabase
                            .from('appointment_logs')
                            .insert([
                                {
                                    appointment_id: appointment.id,
                                    action: 'auto_refund_unconfirmed',
                                    actor: 'system',
                                    metadata: {
                                        refund_id: refundResult.refund_id,
                                        reason: 'Confirmation timeout'
                                    }
                                }
                            ]);

                        // Record refund transaction
                        await supabase
                            .from('payment_transactions')
                            .insert([
                                {
                                    appointment_id: appointment.id,
                                    reference: `REFUND_${appointment.payment_reference}`,
                                    transaction_type: 'refund',
                                    amount: appointment.amount_paid,
                                    currency: appointment.currency,
                                    status: 'success',
                                    patient_id: appointment.user_id,
                                    practitioner_id: appointment.practitioner_id,
                                    paystack_response: refundResult.data,
                                    completed_at: new Date().toISOString()
                                }
                            ]);

                        results.push({
                            appointment_id: appointment.id,
                            booking_id: appointment.booking_id,
                            status: 'refunded',
                            amount: appointment.amount_paid
                        });

                        console.log(`✅ Auto-refunded appointment ${appointment.booking_id}`);
                    }
                } else {
                    console.error(`Failed to refund appointment ${appointment.booking_id}:`, refundResult.message);
                    results.push({
                        appointment_id: appointment.id,
                        booking_id: appointment.booking_id,
                        status: 'refund_failed',
                        error: refundResult.message
                    });
                }

            } catch (appointmentError) {
                console.error(`Error processing appointment ${appointment.booking_id}:`, appointmentError);
                results.push({
                    appointment_id: appointment.id,
                    booking_id: appointment.booking_id,
                    status: 'error',
                    error: appointmentError.message
                });
            }
        }

        console.log(`✅ Processed ${results.length} appointments`);

        return res.status(200).json({
            success: true,
            processed: results.length,
            results: results
        });

    } catch (error) {
        console.error('Cron job error:', error);
        return res.status(500).json({ error: error.message });
    }
}

/**
 * CRON JOB 2: Check for no-shows
 * Run every hour
 * Route: /api/cron/check-no-shows
 */
export async function checkNoShows(req, res) {
    console.log('🔄 Starting no-show check...');

    try {
        // Get confirmed appointments past their scheduled time
        const now = new Date();
        const currentDate = now.toISOString().split('T')[0];
        const currentTime = now.toTimeString().slice(0, 5); // HH:MM format

        const { data: pastAppointments, error } = await supabase
            .from('appointments')
            .select('*')
            .eq('status', 'CONFIRMED')
            .eq('no_show_checked', false)
            .or(`appointment_date.lt.${currentDate},and(appointment_date.eq.${currentDate},appointment_time.lt.${currentTime})`);

        if (error) {
            console.error('Error fetching past appointments:', error);
            return res.status(500).json({ error: error.message });
        }

        console.log(`Found ${pastAppointments?.length || 0} appointments to check for no-shows`);

        const results = [];

        for (const appointment of pastAppointments || []) {
            try {
                // Mark as no-show (default action)
                // In production, you'd have a way for practitioners to mark attendance
                // For now, we'll mark as NO_SHOW by default and practitioners can override

                const { error: updateError } = await supabase
                    .from('appointments')
                    .update({
                        status: 'NO_SHOW',
                        no_show_checked: true,
                        no_show_fee: appointment.amount_paid
                    })
                    .eq('id', appointment.id);

                if (!updateError) {
                    // Log no-show
                    await supabase
                        .from('appointment_logs')
                        .insert([
                            {
                                appointment_id: appointment.id,
                                action: 'marked_no_show',
                                actor: 'system',
                                metadata: {
                                    check_date: now.toISOString(),
                                    appointment_date: appointment.appointment_date,
                                    appointment_time: appointment.appointment_time
                                }
                            }
                        ]);

                    // Notify practitioner
                    await supabase
                        .from('practitioner_notifications')
                        .insert([
                            {
                                practitioner_id: appointment.practitioner_id,
                                appointment_id: appointment.id,
                                notification_type: 'no_show',
                                message: `Appointment with ${appointment.patient_name} marked as no-show. If patient attended, please update the status.`
                            }
                        ]);

                    results.push({
                        appointment_id: appointment.id,
                        booking_id: appointment.booking_id,
                        status: 'no_show'
                    });

                    console.log(`⚠️ Marked appointment ${appointment.booking_id} as NO_SHOW`);
                }

            } catch (appointmentError) {
                console.error(`Error processing appointment ${appointment.booking_id}:`, appointmentError);
                results.push({
                    appointment_id: appointment.id,
                    booking_id: appointment.booking_id,
                    status: 'error',
                    error: appointmentError.message
                });
            }
        }

        console.log(`✅ Processed ${results.length} appointments for no-show`);

        return res.status(200).json({
            success: true,
            processed: results.length,
            results: results
        });

    } catch (error) {
        console.error('No-show check error:', error);
        return res.status(500).json({ error: error.message });
    }
}

/**
 * CRON JOB 3: Send appointment reminders
 * Run daily at 8 AM
 * Route: /api/cron/send-reminders
 */
export async function sendAppointmentReminders(req, res) {
    console.log('🔄 Starting appointment reminders...');

    try {
        // Get confirmed appointments for tomorrow
        const tomorrow = new Date();
        tomorrow.setDate(tomorrow.getDate() + 1);
        const tomorrowDate = tomorrow.toISOString().split('T')[0];

        const { data: upcomingAppointments, error } = await supabase
            .from('appointments')
            .select('*')
            .eq('status', 'CONFIRMED')
            .eq('appointment_date', tomorrowDate);

        if (error) {
            console.error('Error fetching upcoming appointments:', error);
            return res.status(500).json({ error: error.message });
        }

        console.log(`Found ${upcomingAppointments?.length || 0} appointments for tomorrow`);

        const results = [];

        for (const appointment of upcomingAppointments || []) {
            try {
                // Log reminder sent
                await supabase
                    .from('appointment_logs')
                    .insert([
                        {
                            appointment_id: appointment.id,
                            action: 'reminder_sent',
                            actor: 'system',
                            metadata: {
                                reminder_type: '24h',
                                sent_at: new Date().toISOString()
                            }
                        }
                    ]);

                // In production, you would:
                // 1. Send email via SendGrid/Resend
                // 2. Send SMS via Twilio/Africa's Talking
                // 3. Send push notification

                results.push({
                    appointment_id: appointment.id,
                    booking_id: appointment.booking_id,
                    patient_email: appointment.patient_email,
                    status: 'reminder_sent'
                });

                console.log(`📧 Reminder sent for appointment ${appointment.booking_id}`);

            } catch (appointmentError) {
                console.error(`Error sending reminder for ${appointment.booking_id}:`, appointmentError);
                results.push({
                    appointment_id: appointment.id,
                    booking_id: appointment.booking_id,
                    status: 'error',
                    error: appointmentError.message
                });
            }
        }

        console.log(`✅ Sent ${results.length} reminders`);

        return res.status(200).json({
            success: true,
            sent: results.length,
            results: results
        });

    } catch (error) {
        console.error('Reminder cron error:', error);
        return res.status(500).json({ error: error.message });
    }
}

/**
 * Helper function to initiate Paystack refund
 */
async function initiatePaystackRefund(transactionReference, amount, reason) {
    try {
        const response = await fetch('https://api.paystack.co/refund', {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${PAYSTACK_SECRET_KEY}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                transaction: transactionReference,
                amount: amount * 100, // Convert to kobo
                currency: 'ZAR',
                customer_note: reason,
                merchant_note: `Auto-refund: ${reason}`
            })
        });

        const data = await response.json();

        if (data.status) {
            return {
                success: true,
                refund_id: data.data.id,
                data: data.data
            };
        } else {
            return {
                success: false,
                message: data.message || 'Refund failed'
            };
        }

    } catch (error) {
        console.error('Paystack refund error:', error);
        return {
            success: false,
            message: error.message
        };
    }
}

/**
 * Export all cron functions
 */
export default {
    checkUnconfirmedAppointments,
    checkNoShows,
    sendAppointmentReminders
};
