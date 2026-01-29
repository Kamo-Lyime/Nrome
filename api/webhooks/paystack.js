/**
 * PAYSTACK WEBHOOK HANDLER
 * Deploy this as a Vercel Serverless Function or Supabase Edge Function
 * URL: /api/webhooks/paystack
 * 
 * This handles Paystack webhook callbacks for:
 * - charge.success (payment successful)
 * - refund.processed (refund completed)
 * - transfer.success (payout to practitioner)
 */

import { createClient } from '@supabase/supabase-js';
import crypto from 'crypto';

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const PAYSTACK_SECRET_KEY = process.env.PAYSTACK_SECRET_KEY || 'sk_test_ce04e3466d797c150e1b7c81ce8d3a5c51bbc098';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

export default async function handler(req, res) {
    // Only allow POST requests
    if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Method not allowed' });
    }

    // Verify Paystack signature
    const hash = crypto
        .createHmac('sha512', PAYSTACK_SECRET_KEY)
        .update(JSON.stringify(req.body))
        .digest('hex');

    if (hash !== req.headers['x-paystack-signature']) {
        console.error('Invalid webhook signature');
        return res.status(401).json({ error: 'Invalid signature' });
    }

    const event = req.body;
    console.log('Webhook received:', event.event);

    try {
        switch (event.event) {
            case 'charge.success':
                await handleChargeSuccess(event.data);
                break;

            case 'refund.processed':
                await handleRefundProcessed(event.data);
                break;

            case 'transfer.success':
                await handleTransferSuccess(event.data);
                break;

            default:
                console.log('Unhandled event type:', event.event);
        }

        return res.status(200).json({ received: true });

    } catch (error) {
        console.error('Webhook processing error:', error);
        return res.status(500).json({ error: 'Webhook processing failed' });
    }
}

/**
 * Handle successful payment
 */
async function handleChargeSuccess(data) {
    const reference = data.reference;
    const amount = data.amount / 100; // Convert from kobo to rands

    console.log('Processing charge.success:', reference);

    // Find appointment by payment reference
    const { data: appointment, error: fetchError } = await supabase
        .from('appointments')
        .select('*')
        .eq('payment_reference', reference)
        .single();

    if (fetchError || !appointment) {
        console.error('Appointment not found for reference:', reference);
        return;
    }

    // Update appointment to PENDING_CONFIRMATION
    const { error: updateError } = await supabase
        .from('appointments')
        .update({
            status: 'PENDING_CONFIRMATION',
            payment_status: 'success',
            payment_metadata: data
        })
        .eq('id', appointment.id);

    if (updateError) {
        console.error('Error updating appointment:', updateError);
        return;
    }

    // Record transaction
    await supabase
        .from('payment_transactions')
        .insert([
            {
                appointment_id: appointment.id,
                reference: reference,
                paystack_reference: data.reference,
                transaction_type: 'payment',
                amount: amount,
                currency: 'ZAR',
                platform_fee: appointment.platform_fee,
                practitioner_amount: appointment.practitioner_amount,
                status: 'success',
                patient_id: appointment.user_id,
                practitioner_id: appointment.practitioner_id,
                paystack_response: data,
                webhook_data: data,
                completed_at: new Date().toISOString()
            }
        ]);

    // Log the webhook event
    await supabase
        .from('appointment_logs')
        .insert([
            {
                appointment_id: appointment.id,
                action: 'webhook_payment_success',
                actor: 'webhook',
                metadata: { reference: reference }
            }
        ]);

    // Notify practitioner
    await supabase
        .from('practitioner_notifications')
        .insert([
            {
                practitioner_id: appointment.practitioner_id,
                appointment_id: appointment.id,
                notification_type: 'payment_received',
                message: `Payment of R${amount} received for appointment with ${appointment.patient_name}. Please confirm within 24 hours.`
            }
        ]);

    console.log('✅ Charge success processed');
}

/**
 * Handle refund processed
 */
async function handleRefundProcessed(data) {
    const reference = data.transaction_reference;

    console.log('Processing refund.processed:', reference);

    // Find appointment by payment reference
    const { data: appointment, error: fetchError } = await supabase
        .from('appointments')
        .select('*')
        .eq('payment_reference', reference)
        .single();

    if (fetchError || !appointment) {
        console.error('Appointment not found for refund reference:', reference);
        return;
    }

    // Update appointment status to REFUNDED
    const { error: updateError } = await supabase
        .from('appointments')
        .update({
            status: 'REFUNDED',
            payment_status: 'refunded',
            refunded_at: new Date().toISOString()
        })
        .eq('id', appointment.id);

    if (updateError) {
        console.error('Error updating refund status:', updateError);
        return;
    }

    // Record refund transaction
    await supabase
        .from('payment_transactions')
        .insert([
            {
                appointment_id: appointment.id,
                reference: `REFUND_${reference}`,
                paystack_reference: data.id,
                transaction_type: 'refund',
                amount: data.amount / 100,
                currency: 'ZAR',
                status: 'success',
                patient_id: appointment.user_id,
                practitioner_id: appointment.practitioner_id,
                paystack_response: data,
                webhook_data: data,
                completed_at: new Date().toISOString()
            }
        ]);

    // Log refund
    await supabase
        .from('appointment_logs')
        .insert([
            {
                appointment_id: appointment.id,
                action: 'webhook_refund_processed',
                actor: 'webhook',
                metadata: { refund_id: data.id }
            }
        ]);

    console.log('✅ Refund processed');
}

/**
 * Handle transfer success (payout to practitioner)
 */
async function handleTransferSuccess(data) {
    console.log('Processing transfer.success:', data.reference);

    // Log transfer for audit purposes
    // You can track practitioner payouts here if needed

    console.log('✅ Transfer success logged');
}
