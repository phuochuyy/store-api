# frozen_string_literal: true

# Create payment methods
payment_methods_data = [
  {
    name: 'Credit Card (Stripe)',
    description: 'Pay securely with your credit or debit card through Stripe',
    gateway_type: 'stripe',
    processing_fee_percentage: 2.9,
    processing_fee_fixed: 0.30,
    gateway_config: {
      publishable_key: 'pk_test_1234567890',
      secret_key: 'sk_test_1234567890',
      webhook_secret: 'whsec_1234567890'
    }
  },
  {
    name: 'PayPal',
    description: 'Pay with your PayPal account',
    gateway_type: 'paypal',
    processing_fee_percentage: 3.4,
    processing_fee_fixed: 0.35,
    gateway_config: {
      client_id: 'paypal_client_id_123',
      client_secret: 'paypal_client_secret_123',
      environment: 'sandbox'
    }
  },
  {
    name: 'Bank Transfer',
    description: 'Transfer money directly from your bank account',
    gateway_type: 'bank_transfer',
    processing_fee_percentage: 0.0,
    processing_fee_fixed: 0.0,
    gateway_config: {
      bank_account: '1234567890',
      routing_number: '021000021',
      account_name: 'Store API Account',
      instructions: 'Please include your order number in the transfer reference'
    }
  },
  {
    name: 'Cash on Delivery',
    description: 'Pay with cash when your order is delivered',
    gateway_type: 'cash_on_delivery',
    processing_fee_percentage: 0.0,
    processing_fee_fixed: 0.0,
    gateway_config: {
      delivery_fee: 5.00,
      instructions: 'Payment will be collected upon delivery'
    }
  },
  {
    name: 'Digital Wallet',
    description: 'Pay with your digital wallet',
    gateway_type: 'wallet',
    processing_fee_percentage: 1.5,
    processing_fee_fixed: 0.25,
    gateway_config: {
      wallet_provider: 'generic',
      api_key: 'wallet_api_key_123',
      api_secret: 'wallet_api_secret_123'
    }
  }
]

puts 'Creating payment methods...'

payment_methods_data.each do |method_data|
  payment_method = PaymentMethod.find_or_create_by(name: method_data[:name]) do |pm|
    pm.description = method_data[:description]
    pm.gateway_type = method_data[:gateway_type]
    pm.processing_fee_percentage = method_data[:processing_fee_percentage]
    pm.processing_fee_fixed = method_data[:processing_fee_fixed]
    pm.gateway_config = method_data[:gateway_config]
    pm.is_active = true
  end

  if payment_method.persisted?
    puts "✓ Created payment method: #{payment_method.name}"
  else
    puts "✗ Failed to create payment method: #{payment_method.name}"
    puts "  Errors: #{payment_method.errors.full_messages.join(', ')}"
  end
end

puts 'Payment methods seeding completed!'
