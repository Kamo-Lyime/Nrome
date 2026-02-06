/**
 * PAYSTACK INTEGRATION MODULE
 * Handles all Paystack payment operations for appointment bookings
 * Includes split payments, refunds, and subaccount management
 */

class PaystackIntegration {
    constructor() {
        // Use key from config.js (same as medication ordering)
        this.publicKey = window.CONFIG?.PAYSTACK_PUBLIC_KEY || 'pk_test_4ce27df0ac8e3de5c846f0ec47b7fb5c83b1c5df';
        this.secretKey = 'sk_test_ce04e3466d797c150e1b7c81ce8d3a5c51bbc098';
        this.baseUrl = 'https://api.paystack.co';
        
        // Platform configuration
        this.platformFeePercentage = 20; // 20% platform fee
        this.practitionerPercentage = 80; // 80% to practitioner
        this.defaultAmount = 50000; // R500.00 in kobo (Paystack uses smallest currency unit)
        this.currency = 'ZAR';
        
        // Confirmation settings
        this.confirmationTimeoutHours = 24; // Practitioner has 24 hours to confirm
        this.cancellationHours = 24; // 24-hour cancellation policy
    }

    /**
     * Initialize Paystack inline payment
     * Opens payment modal for patient to pay
     */
    async initiatePayment(appointmentData, onSuccess, onClose) {
        const {
            amount = this.defaultAmount,
            email,
            reference,
            metadata = {}
        } = appointmentData;

        const handler = PaystackPop.setup({
            key: this.publicKey,
            email: email,
            amount: amount, // Amount in kobo
            currency: this.currency,
            ref: reference,
            metadata: {
                ...metadata,
                appointment_id: appointmentData.id,
                patient_name: appointmentData.patient_name,
                practitioner_id: appointmentData.practitioner_id,
                custom_fields: [
                    {
                        display_name: "Appointment Date",
                        variable_name: "appointment_date",
                        value: appointmentData.appointment_date
                    },
                    {
                        display_name: "Appointment Time",
                        variable_name: "appointment_time",
                        value: appointmentData.appointment_time
                    }
                ]
            },
            onClose: function() {
                console.log('Payment window closed');
                if (onClose) onClose();
            },
            callback: function(response) {
                console.log('Payment successful:', response);
                if (onSuccess) onSuccess(response);
            }
        });

        handler.openIframe();
    }

    /**
     * Verify payment transaction with Paystack
     * Called after payment callback to confirm transaction
     */
    async verifyPayment(reference) {
        try {
            const response = await fetch(`${this.baseUrl}/transaction/verify/${reference}`, {
                method: 'GET',
                headers: {
                    'Authorization': `Bearer ${this.secretKey}`,
                    'Content-Type': 'application/json'
                }
            });

            const data = await response.json();

            if (data.status && data.data.status === 'success') {
                return {
                    success: true,
                    data: data.data,
                    amount: data.data.amount / 100, // Convert from kobo to rands
                    reference: data.data.reference,
                    paidAt: data.data.paid_at
                };
            } else {
                return {
                    success: false,
                    message: data.message || 'Payment verification failed'
                };
            }
        } catch (error) {
            console.error('Payment verification error:', error);
            return {
                success: false,
                message: error.message
            };
        }
    }

    /**
     * Create a subaccount for a practitioner
     * Called when practitioner registers - enables automatic payment splits
     */
    async createSubaccount(practitionerData) {
        const {
            business_name,
            account_number,
            bank_code,
            percentage_charge = this.practitionerPercentage,
            practitioner_id,
            email
        } = practitionerData;

        try {
            const response = await fetch(`${this.baseUrl}/subaccount`, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${this.secretKey}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    business_name: business_name,
                    settlement_bank: account_number,
                    account_number: account_number,
                    percentage_charge: percentage_charge,
                    description: `Medical Practitioner: ${business_name}`,
                    primary_contact_email: email,
                    primary_contact_name: business_name,
                    primary_contact_phone: practitionerData.phone || '',
                    metadata: {
                        practitioner_id: practitioner_id,
                        created_via: 'nrome_platform'
                    }
                })
            });

            const data = await response.json();

            if (data.status) {
                return {
                    success: true,
                    subaccount_code: data.data.subaccount_code,
                    data: data.data
                };
            } else {
                return {
                    success: false,
                    message: data.message || 'Subaccount creation failed'
                };
            }
        } catch (error) {
            console.error('Subaccount creation error:', error);
            return {
                success: false,
                message: error.message
            };
        }
    }

    /**
     * Initiate a refund
     * Used for cancellations, no-shows, or unconfirmed appointments
     */
    async initiateRefund(transactionReference, amount, reason = 'Appointment cancellation') {
        try {
            // Note: Paystack refunds API may vary by region
            // For South Africa, check Paystack documentation for specific endpoint
            const response = await fetch(`${this.baseUrl}/refund`, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${this.secretKey}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    transaction: transactionReference,
                    amount: amount * 100, // Convert to kobo
                    currency: this.currency,
                    customer_note: reason,
                    merchant_note: `Refund: ${reason}`
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
                    message: data.message || 'Refund initiation failed'
                };
            }
        } catch (error) {
            console.error('Refund error:', error);
            return {
                success: false,
                message: error.message
            };
        }
    }

    /**
     * List all banks (for practitioner registration)
     */
    async listBanks(country = 'south africa') {
        try {
            const response = await fetch(`${this.baseUrl}/bank?country=${country}`, {
                method: 'GET',
                headers: {
                    'Authorization': `Bearer ${this.secretKey}`,
                    'Content-Type': 'application/json'
                }
            });

            const data = await response.json();

            if (data.status) {
                return {
                    success: true,
                    banks: data.data
                };
            } else {
                return {
                    success: false,
                    message: data.message
                };
            }
        } catch (error) {
            console.error('Banks list error:', error);
            return {
                success: false,
                message: error.message
            };
        }
    }

    /**
     * Resolve account number (verify bank account before creating subaccount)
     */
    async resolveAccountNumber(accountNumber, bankCode) {
        try {
            const response = await fetch(
                `${this.baseUrl}/bank/resolve?account_number=${accountNumber}&bank_code=${bankCode}`,
                {
                    method: 'GET',
                    headers: {
                        'Authorization': `Bearer ${this.secretKey}`,
                        'Content-Type': 'application/json'
                    }
                }
            );

            const data = await response.json();

            if (data.status) {
                return {
                    success: true,
                    account_name: data.data.account_name,
                    account_number: data.data.account_number
                };
            } else {
                return {
                    success: false,
                    message: data.message || 'Account verification failed'
                };
            }
        } catch (error) {
            console.error('Account resolution error:', error);
            return {
                success: false,
                message: error.message
            };
        }
    }

    /**
     * Calculate payment split
     * Returns platform fee and practitioner amount
     */
    calculateSplit(totalAmount) {
        const platformFee = (totalAmount * this.platformFeePercentage) / 100;
        const practitionerAmount = totalAmount - platformFee;

        return {
            total: totalAmount,
            platformFee: platformFee,
            practitionerAmount: practitionerAmount,
            platformPercentage: this.platformFeePercentage,
            practitionerPercentage: this.practitionerPercentage
        };
    }

    /**
     * Generate unique payment reference
     */
    generateReference(prefix = 'APT') {
        const timestamp = Date.now();
        const random = Math.floor(Math.random() * 10000);
        return `${prefix}_${timestamp}_${random}`;
    }

    /**
     * Calculate confirmation deadline
     */
    getConfirmationDeadline() {
        const deadline = new Date();
        deadline.setHours(deadline.getHours() + this.confirmationTimeoutHours);
        return deadline.toISOString();
    }

    /**
     * Check if cancellation is eligible for full refund
     */
    isFullRefundEligible(appointmentDate, appointmentTime) {
        const now = new Date();
        const appointmentDateTime = new Date(`${appointmentDate} ${appointmentTime}`);
        const hoursDifference = (appointmentDateTime - now) / (1000 * 60 * 60);

        return hoursDifference >= this.cancellationHours;
    }

    /**
     * Format amount for display
     */
    formatAmount(amount, currency = 'ZAR') {
        return new Intl.NumberFormat('en-ZA', {
            style: 'currency',
            currency: currency
        }).format(amount);
    }
}

// Export for use in other modules
window.PaystackIntegration = PaystackIntegration;
console.log('✅ Paystack Integration Module Loaded');
