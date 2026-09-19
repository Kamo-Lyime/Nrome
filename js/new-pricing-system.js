// =====================================================
// NEW PRICING SYSTEM - 5% Platform Fee + Medical Aid
// =====================================================

class NewPricingSystem {
    constructor() {
        this.PLATFORM_FEE_PERCENTAGE = 0.05; // 5% platform fee
        this.MEDICAL_AID_FEE = 1000; // R10 in cents
        this.VERIFICATION_BADGE_COST = 14900; // R149 in cents
    }

    // Calculate payment breakdown with new 5% fee structure
    calculatePaymentBreakdown(consultationFee, isMedicalAid = false, currency = 'ZAR') {
        const consultationFeeInCents = Math.round(consultationFee * 100);
        
        // Platform fee: 5% of consultation
        const platformFeeInCents = Math.round(consultationFeeInCents * this.PLATFORM_FEE_PERCENTAGE);
        
        // Medical aid fee: R10 if applicable
        const medicalAidFeeInCents = isMedicalAid ? this.MEDICAL_AID_FEE : 0;
        
        // Paystack processing fee (calculated on total)
        const paystackFeeInCents = this.calculatePaystackFee(consultationFeeInCents + platformFeeInCents, currency);
        
        // Total amount patient pays
        const totalInCents = consultationFeeInCents + platformFeeInCents + paystackFeeInCents;
        
        // Practitioner receives: consultation fee - medical aid fee (if applicable)
        const practitionerReceivesInCents = consultationFeeInCents - medicalAidFeeInCents;
        
        return {
            consultationFee: consultationFeeInCents / 100,
            platformFee: platformFeeInCents / 100,
            medicalAidFee: medicalAidFeeInCents / 100,
            paystackFee: paystackFeeInCents / 100,
            total: totalInCents / 100,
            practitionerReceives: practitionerReceivesInCents / 100,
            currency: currency,
            breakdown: {
                consultationFeeCents: consultationFeeInCents,
                platformFeeCents: platformFeeInCents,
                medicalAidFeeCents: medicalAidFeeInCents,
                paystackFeeCents: paystackFeeInCents,
                totalCents: totalInCents,
                practitionerReceivesCents: practitionerReceivesInCents
            }
        };
    }

    // Calculate Paystack processing fee based on currency
    calculatePaystackFee(amountInCents, currency) {
        const amount = amountInCents / 100;
        let feeInCents = 0;
        
        switch (currency) {
            case 'ZAR':
                // 1.5% + R1 (capped at R50)
                feeInCents = Math.min(Math.round(amountInCents * 0.015) + 100, 5000);
                break;
            case 'NGN':
                // 1.5% + ₦100 (capped at ₦2000)
                feeInCents = Math.min(Math.round(amountInCents * 0.015) + 10000, 200000);
                break;
            case 'KES':
                // 1.5% + KSh5
                feeInCents = Math.round(amountInCents * 0.015) + 500;
                break;
            case 'GHS':
                // 1.95%
                feeInCents = Math.round(amountInCents * 0.0195);
                break;
            case 'USD':
            case 'EUR':
                // 3.9% + $0.10
                feeInCents = Math.round(amountInCents * 0.039) + 10;
                break;
            default:
                // Default: 3.9%
                feeInCents = Math.round(amountInCents * 0.039);
        }
        
        return Math.round(feeInCents);
    }

    // Format payment breakdown for display
    formatPaymentSummary(breakdown) {
        return `
💳 PAYMENT BREAKDOWN
━━━━━━━━━━━━━━━━━━━━━━━━━
Consultation Fee: ${this.formatCurrency(breakdown.consultationFee, breakdown.currency)}
Platform Fee (5%): ${this.formatCurrency(breakdown.platformFee, breakdown.currency)}
${breakdown.medicalAidFee > 0 ? `Medical Aid Fee: ${this.formatCurrency(breakdown.medicalAidFee, breakdown.currency)}\n` : ''}Processing Fee: ${this.formatCurrency(breakdown.paystackFee, breakdown.currency)}
━━━━━━━━━━━━━━━━━━━━━━━━━
TOTAL TO PAY: ${this.formatCurrency(breakdown.total, breakdown.currency)}

Practitioner receives: ${this.formatCurrency(breakdown.practitionerReceives, breakdown.currency)} (95%)
        `.trim();
    }

    // Check if practitioner can accept bookings
    async canPractitionerAcceptBookings(practitionerId) {
        try {
            const { data: practitioner, error } = await supabaseClient
                .from('practitioners')
                .select('medical_aid_fee_balance, can_accept_bookings, verification_status')
                .eq('id', practitionerId)
                .single();
            
            if (error) throw error;
            
            return {
                canAccept: practitioner.can_accept_bookings && 
                          practitioner.medical_aid_fee_balance === 0 &&
                          practitioner.verification_status === 'verified',
                balance: practitioner.medical_aid_fee_balance || 0,
                reason: this.getBlockingReason(practitioner)
            };
        } catch (error) {
            console.error('Error checking practitioner status:', error);
            return { canAccept: false, balance: 0, reason: 'Unable to verify practitioner status' };
        }
    }

    getBlockingReason(practitioner) {
        if (practitioner.verification_status !== 'verified') {
            return 'Practitioner not verified';
        }
        if (practitioner.medical_aid_fee_balance > 0) {
            return `Outstanding medical aid fees: R${(practitioner.medical_aid_fee_balance / 100).toFixed(2)}`;
        }
        if (!practitioner.can_accept_bookings) {
            return 'Practitioner temporarily unavailable';
        }
        return null;
    }

    // Add medical aid fee when practitioner accepts medical aid booking
    async addMedicalAidFee(practitionerId, appointmentId = null) {
        try {
            const { data, error } = await supabaseClient
                .rpc('add_medical_aid_fee', {
                    practitioner_uuid: practitionerId
                });
            
            if (error) throw error;
            
            console.log('✅ Medical aid fee added (R10). Practitioner must clear balance to accept new bookings.');
            return data;
        } catch (error) {
            console.error('Error adding medical aid fee:', error);
            throw error;
        }
    }

    // Pay medical aid fee balance
    async payMedicalAidFees(practitionerId, patientEmail, patientName) {
        try {
            // Get current balance
            const { data: practitioner, error: fetchError } = await supabaseClient
                .from('practitioners')
                .select('medical_aid_fee_balance, full_name')
                .eq('id', practitionerId)
                .single();
            
            if (fetchError) throw fetchError;
            
            const balanceInCents = practitioner.medical_aid_fee_balance || 0;
            
            if (balanceInCents === 0) {
                alert('✅ No outstanding medical aid fees.');
                return;
            }
            
            // Initiate Paystack payment for balance
            const paymentReference = `MEDFEE_${practitionerId}_${Date.now()}`;
            
            const paystackHandler = new PaystackIntegration();
            paystackHandler.initiatePayment(
                {
                    amount: balanceInCents,
                    email: patientEmail,
                    reference: paymentReference,
                    metadata: {
                        type: 'medical_aid_fee',
                        practitioner_id: practitionerId,
                        practitioner_name: practitioner.full_name
                    }
                },
                async (response) => {
                    console.log('✅ Medical aid fee payment successful:', response);
                    
                    // Clear fees in database
                    await this.clearMedicalAidFees(practitionerId, response.reference);
                    
                    alert(`✅ Medical aid fees paid successfully!\n\nAmount: R${(balanceInCents / 100).toFixed(2)}\nYou can now accept new bookings.`);
                    
                    // Reload page to update status
                    window.location.reload();
                },
                (error) => {
                    console.error('❌ Payment failed:', error);
                    alert('Payment failed. Please try again.');
                }
            );
        } catch (error) {
            console.error('Error processing medical aid fee payment:', error);
            alert('Error: ' + error.message);
        }
    }

    // Clear medical aid fee balance after payment
    async clearMedicalAidFees(practitionerId, paymentReference) {
        try {
            const { data, error } = await supabaseClient
                .rpc('clear_medical_aid_fees', {
                    practitioner_uuid: practitionerId,
                    payment_ref: paymentReference
                });
            
            if (error) throw error;
            
            console.log('✅ Medical aid fees cleared successfully');
            return data;
        } catch (error) {
            console.error('Error clearing medical aid fees:', error);
            throw error;
        }
    }

    // Purchase verification badge (R149 once-off)
    async purchaseVerificationBadge(practitionerId, patientEmail, patientName) {
        try {
            // Check if already purchased
            const { data: practitioner, error: fetchError } = await supabaseClient
                .from('practitioners')
                .select('verified_badge, full_name')
                .eq('id', practitionerId)
                .single();
            
            if (fetchError) throw fetchError;
            
            if (practitioner.verified_badge) {
                alert('✅ You already have a verified badge!');
                return;
            }
            
            // Create payment reference
            const paymentReference = `BADGE_${practitionerId}_${Date.now()}`;
            
            // Insert payment record
            const { error: insertError } = await supabaseClient
                .from('verification_badge_payments')
                .insert({
                    practitioner_id: practitionerId,
                    amount: this.VERIFICATION_BADGE_COST,
                    payment_reference: paymentReference,
                    payment_status: 'pending'
                });
            
            if (insertError) throw insertError;
            
            // Initiate Paystack payment
            const paystackHandler = new PaystackIntegration();
            paystackHandler.initiatePayment(
                {
                    amount: this.VERIFICATION_BADGE_COST,
                    email: patientEmail,
                    reference: paymentReference,
                    metadata: {
                        type: 'verification_badge',
                        practitioner_id: practitionerId,
                        practitioner_name: practitioner.full_name
                    }
                },
                async (response) => {
                    console.log('✅ Verification badge payment successful:', response);
                    
                    // Activate badge in database
                    await this.activateVerificationBadge(practitionerId, response.reference);
                    
                    alert(`🎉 VERIFICATION BADGE ACTIVATED!\n\n✅ You are now a verified practitioner!\n✅ Your profile will be prioritized by AI\n✅ You'll appear at the top of all listings\n\nThank you for joining our verified network!`);
                    
                    // Reload page to show badge
                    window.location.reload();
                },
                (error) => {
                    console.error('❌ Payment failed:', error);
                    alert('Payment failed. Please try again.');
                }
            );
        } catch (error) {
            console.error('Error purchasing verification badge:', error);
            alert('Error: ' + error.message);
        }
    }

    // Activate verification badge after payment
    async activateVerificationBadge(practitionerId, paymentReference) {
        try {
            const { data, error } = await supabaseClient
                .rpc('activate_verification_badge', {
                    practitioner_uuid: practitionerId,
                    payment_ref: paymentReference
                });
            
            if (error) throw error;
            
            console.log('✅ Verification badge activated successfully');
            return data;
        } catch (error) {
            console.error('Error activating verification badge:', error);
            throw error;
        }
    }

    // Format currency display
    formatCurrency(amount, currency) {
        const symbols = {
            'ZAR': 'R',
            'NGN': '₦',
            'KES': 'KSh',
            'GHS': 'GH₵',
            'USD': '$',
            'EUR': '€'
        };
        
        const symbol = symbols[currency] || currency;
        return `${symbol}${amount.toFixed(2)}`;
    }
}

// Initialize pricing system globally
const pricingSystem = new NewPricingSystem();

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
    module.exports = NewPricingSystem;
}
