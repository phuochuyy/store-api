# frozen_string_literal: true

# Seeds for missing tables: coupons, payments, payment_histories, product_reviews,
# product_wishlists, product_comparisons, product_comparison_items, stock_movements, user_addresses

Rails.logger.debug 'Creating seeds for missing tables...'

# ============================================================================
# COUPONS
# ============================================================================
Rails.logger.debug 'Creating coupons...'

if Discount.exists? && User.exists?
  discounts = Discount.all
  customers = User.where(role: 'customer')

  # Create active coupons for customers
  customers.limit(5).each do |customer|
    discount = discounts.sample
    coupon = Coupon.create!(
      discount: discount,
      user: customer,
      code: "COUPON#{SecureRandom.hex(4).upcase}",
      status: 'active',
      discount_amount: discount.value
    )
    Rails.logger.debug { "Created coupon #{coupon.code} for #{customer.email}" }
  end

  # Create some used coupons
  if Order.exists?
    orders = Order.where(status: %w[delivered shipped confirmed]).limit(3)
    orders.each do |order|
      discount = discounts.sample
      customer = customers.sample
      discount_amount = begin
        discount.calculate_discount(order.total_amount)
      rescue StandardError
        discount.discount_type == 'percentage' ? (order.total_amount * discount.value / 100.0) : discount.value
      end

      coupon = Coupon.create!(
        discount: discount,
        user: customer,
        order: order,
        code: "COUPON#{SecureRandom.hex(4).upcase}",
        status: 'used',
        used_at: order.created_at,
        discount_amount: discount_amount
      )
      Rails.logger.debug { "Created used coupon #{coupon.code} for order #{order.id}" }
    end
  end
end

Rails.logger.debug { "Total coupons created: #{Coupon.count}" }

# ============================================================================
# PAYMENTS & PAYMENT HISTORIES
# ============================================================================
Rails.logger.debug 'Creating payments and payment histories...'

if Order.exists? && PaymentMethod.exists?
  orders = Order.where(status: %w[delivered shipped confirmed pending]).limit(10)
  payment_methods = PaymentMethod.where(is_active: true)

  orders.each do |order|
    payment_method = payment_methods.sample
    statuses = %w[completed pending processing failed]
    status = statuses.sample

    payment = Payment.create!(
      order: order,
      payment_method: payment_method,
      amount: order.total_amount,
      status: status,
      transaction_id: status == 'completed' ? "TXN_#{SecureRandom.hex(8).upcase}" : nil,
      currency: 'USD',
      processed_at: status == 'completed' ? order.created_at + 1.hour : nil,
      gateway_response: if status == 'completed'
                          {
                            'gateway' => payment_method.gateway_type,
                            'transaction_id' => "TXN_#{SecureRandom.hex(8).upcase}",
                            'status' => 'success'
                          }.to_json
                        end,
      metadata: {
        'card_last_four' => rand(1000..9999).to_s,
        'card_brand' => %w[visa mastercard amex].sample,
        'payment_processor' => payment_method.name.downcase.gsub(' ', '_')
      }
    )

    # Create payment history for the payment
    # Use direct SQL insert since PaymentHistory model might not exist
    begin
      conn = ActiveRecord::Base.connection
      now = Time.current

      # Insert payment creation history
      conn.execute(
        'INSERT INTO payment_histories (payment_id, action, new_status, amount, transaction_id, ' \
        'gateway_response, performed_by, performed_at, notes, created_at, updated_at) ' \
        "VALUES (#{payment.id}, 'create', #{conn.quote(payment.status)}, #{payment.amount}, " \
        "#{payment.transaction_id ? conn.quote(payment.transaction_id) : 'NULL'}, " \
        "#{payment.gateway_response ? conn.quote(payment.gateway_response) : 'NULL'}, " \
        "'System', #{conn.quote(payment.created_at)}, 'Payment created via seed data', " \
        "#{conn.quote(now)}, #{conn.quote(now)})"
      )

      # Add status change history if payment is completed
      if payment.completed?
        conn.execute(
          'INSERT INTO payment_histories (payment_id, action, previous_status, new_status, amount, ' \
          'transaction_id, performed_by, performed_at, notes, created_at, updated_at) ' \
          "VALUES (#{payment.id}, 'status_change', 'pending', 'completed', #{payment.amount}, " \
          "#{payment.transaction_id ? conn.quote(payment.transaction_id) : 'NULL'}, " \
          "'System', #{conn.quote(payment.processed_at)}, 'Payment processed successfully', " \
          "#{conn.quote(now)}, #{conn.quote(now)})"
        )
      end
    rescue StandardError => e
      Rails.logger.warn { "Could not create payment history: #{e.message}" }
    end

    Rails.logger.debug { "Created payment #{payment.id} for order #{order.id} with status #{payment.status}" }
  end
end

Rails.logger.debug { "Total payments created: #{Payment.count}" }
payment_history_count = begin
  ActiveRecord::Base.connection.execute('SELECT COUNT(*) FROM payment_histories').first[0]
rescue StandardError
  0
end
Rails.logger.debug { "Total payment histories created: #{payment_history_count}" }

# ============================================================================
# PRODUCT REVIEWS
# ============================================================================
Rails.logger.debug 'Creating product reviews...'

if Product.exists? && User.exists?
  products = Product.all
  customers = User.where(role: 'customer')

  # Create reviews for various products
  products.sample(15).each do |product|
    customer = customers.sample
    next if ProductReview.exists?(user: customer, product: product)

    ProductReview.create!(
      user: customer,
      product: product,
      rating: rand(3..5), # Mostly positive reviews
      title: [
        'Great product!',
        'Highly recommend',
        'Good value for money',
        'Excellent quality',
        'Love it!',
        'Worth the price',
        'Amazing features',
        'Best purchase',
        'Very satisfied',
        'Exceeded expectations'
      ].sample,
      content: [
        'This product exceeded my expectations. The quality is outstanding and the features are exactly what I needed.',
        "I've been using this for a while now and I'm very happy with my purchase. Highly recommend!",
        'Great value for money. The build quality is solid and it works perfectly for my needs.',
        'Excellent product with great features. The customer service was also very helpful.',
        "I'm very satisfied with this purchase. It's exactly as described and works great."
      ].sample,
      helpful_count: rand(0..50),
      verified_purchase: [true, false].sample,
      status: %w[approved pending].sample,
      created_at: rand(30.days.ago..Time.current)
    )
    Rails.logger.debug { "Created review for #{product.name} by #{customer.name}" }
  end

  # Create some negative reviews
  products.sample(3).each do |product|
    customer = customers.sample
    next if ProductReview.exists?(user: customer, product: product)

    ProductReview.create!(
      user: customer,
      product: product,
      rating: rand(1..2),
      title: 'Not as expected',
      content: "The product didn't meet my expectations. There were some issues with quality.",
      helpful_count: rand(0..10),
      verified_purchase: false,
      status: 'approved',
      created_at: rand(30.days.ago..Time.current)
    )
  end
end

Rails.logger.debug { "Total product reviews created: #{ProductReview.count}" }

# ============================================================================
# PRODUCT WISHLISTS
# ============================================================================
Rails.logger.debug 'Creating product wishlists...'

if Product.exists? && User.exists?
  products = Product.all
  customers = User.where(role: 'customer')

  customers.each do |customer|
    # Each customer has 3-8 wishlist items
    wishlist_products = products.sample(rand(3..8))
    wishlist_products.each do |product|
      next if ProductWishlist.exists?(user: customer, product: product)

      ProductWishlist.create!(
        user: customer,
        product: product,
        notes: [
          'Want to buy this soon',
          'Waiting for price drop',
          'Birthday gift idea',
          'For next upgrade',
          nil
        ].sample,
        priority: rand(0..5),
        created_at: rand(60.days.ago..Time.current)
      )
    end
    Rails.logger.debug { "Created wishlist for #{customer.name} with #{customer.product_wishlists.count} items" }
  end
end

Rails.logger.debug { "Total product wishlists created: #{ProductWishlist.count}" }

# ============================================================================
# PRODUCT COMPARISONS & PRODUCT COMPARISON ITEMS
# ============================================================================
Rails.logger.debug 'Creating product comparisons...'

# Skip product comparisons for now due to validation issues
# TODO: Fix ProductComparison validation to handle product_ids properly
Rails.logger.debug 'Skipping product comparisons (to be fixed)'

# if Product.exists? && User.exists?
#   products = Product.all.to_a
#   customers = User.where(role: 'customer')
#
#   unless products.empty?
#     customers.limit(5).each do |customer|
#       # Create 1-3 comparisons per customer
#       rand(1..3).times do
#         num_products = [rand(2..4), products.size].min
#         comparison_products = products.sample(num_products).compact.reject { |p| p.nil? || p.id.nil? || p.id.zero? }
#
#         next if comparison_products.empty?
#
#         # Create comparison using add_product method
#         comparison = ProductComparison.create!(
#           user: customer,
#           name: "Comparison #{rand(1..100)}",
#           is_public: [true, false].sample
#         )
#
#         comparison_products.each_with_index do |product, index|
#           next if product.id.zero?
#           comparison.add_product(product, position: index)
#         end
#
#         # Set product_ids after items are added
#         comparison.update_column(:product_ids, comparison_products.map(&:id).to_json)
#       end
#     end
#   end
# end

Rails.logger.debug { "Total product comparisons created: #{ProductComparison.count}" }
Rails.logger.debug { "Total product comparison items created: #{ProductComparisonItem.count}" }

# ============================================================================
# STOCK MOVEMENTS
# ============================================================================
Rails.logger.debug 'Creating stock movements...'

if Product.exists?
  products = Product.all
  admin_user = User.find_by(role: 'admin')

  # Create various stock movements
  products.sample(20).each do |product|
    movement_types = %w[in out adjustment return damage transfer]
    movement_type = movement_types.sample

    quantity_change = case movement_type
                      when 'in', 'return'
                        rand(10..100)
                      when 'out', 'damage'
                        -rand(1..50)
                      when 'adjustment'
                        rand(-20..20)
                      when 'transfer'
                        -rand(5..30)
                      else
                        rand(-10..10)
                      end

    previous_quantity = product.stock_quantity
    new_quantity = [previous_quantity + quantity_change, 0].max

    StockMovement.create!(
      product: product,
      movement_type: movement_type,
      quantity: quantity_change,
      previous_quantity: previous_quantity,
      new_quantity: new_quantity,
      reason: [
        'Initial stock',
        'Restock',
        'Sale',
        'Return',
        'Damaged goods',
        'Inventory adjustment',
        'Transfer to other location',
        'Quality control',
        nil
      ].sample,
      reference_type: movement_type == 'out' && Order.exists? ? 'Order' : nil,
      reference_id: movement_type == 'out' && Order.exists? ? Order.all.sample&.id : nil,
      user: admin_user,
      created_at: rand(90.days.ago..Time.current)
    )

    # Update product stock if needed (for demo purposes)
    # In real app, this would be handled by the stock management service
  end
end

Rails.logger.debug { "Total stock movements created: #{StockMovement.count}" }

# ============================================================================
# USER ADDRESSES
# ============================================================================
Rails.logger.debug 'Creating user addresses...'

if User.exists?
  customers = User.where(role: 'customer')

  customers.each do |customer|
    # Each customer has 1-3 addresses
    rand(1..3).times do |index|
      address_types = %w[shipping billing]
      address_type = address_types[index % 2] || 'shipping'

      UserAddress.create!(
        user: customer,
        address_type: address_type,
        full_name: customer.name || "Customer #{customer.id}",
        phone: "+1-555-#{rand(1000..9999)}",
        address_line1: "#{rand(100..9999)} Main Street",
        address_line2: index.zero? ? nil : "Apt #{rand(1..100)}",
        city: ['New York', 'Los Angeles', 'Chicago', 'Houston', 'Phoenix', 'Philadelphia'].sample,
        state: %w[NY CA IL TX AZ PA].sample,
        postal_code: rand(10_000..99_999).to_s,
        country: 'US',
        is_default: index.zero?,
        created_at: rand(180.days.ago..Time.current)
      )
    end

    Rails.logger.debug { "Created addresses for #{customer.name}" }
  end
end

Rails.logger.debug { "Total user addresses created: #{UserAddress.count}" }

# ============================================================================
# SUMMARY
# ============================================================================
Rails.logger.debug '=' * 60
Rails.logger.debug 'MISSING TABLES SEEDS SUMMARY:'
Rails.logger.debug { "- Coupons: #{Coupon.count}" }
Rails.logger.debug { "- Payments: #{Payment.count}" }
Rails.logger.debug { "- Payment Histories: #{PaymentHistory.count}" } if defined?(PaymentHistory)
Rails.logger.debug { "- Product Reviews: #{ProductReview.count}" }
Rails.logger.debug { "- Product Wishlists: #{ProductWishlist.count}" }
Rails.logger.debug { "- Product Comparisons: #{ProductComparison.count}" }
Rails.logger.debug { "- Product Comparison Items: #{ProductComparisonItem.count}" }
Rails.logger.debug { "- Stock Movements: #{StockMovement.count}" }
Rails.logger.debug { "- User Addresses: #{UserAddress.count}" }
Rails.logger.debug '=' * 60
Rails.logger.debug 'Missing tables seeds completed!'
