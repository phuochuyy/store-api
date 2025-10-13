# Discount Seeds
Rails.logger.debug 'Creating discount seeds...'

# Percentage discount
Discount.create!(
  name: 'Welcome Discount',
  description: '10% off for new customers',
  discount_type: 'percentage',
  value: 10.0,
  minimum_amount: 50.0,
  maximum_discount: 25.0,
  usage_limit: 100,
  used_count: 0,
  start_date: Time.current,
  end_date: 30.days.from_now,
  is_active: true,
  code: 'WELCOME10',
  applies_to: 'all'
)

# Fixed amount discount
Discount.create!(
  name: 'Holiday Special',
  description: '$20 off orders over $100',
  discount_type: 'fixed_amount',
  value: 20.0,
  minimum_amount: 100.0,
  usage_limit: 50,
  used_count: 0,
  start_date: Time.current,
  end_date: 60.days.from_now,
  is_active: true,
  code: 'HOLIDAY20',
  applies_to: 'all'
)

# Free shipping discount
Discount.create!(
  name: 'Free Shipping',
  description: 'Free shipping on all orders',
  discount_type: 'free_shipping',
  value: 0.0,
  minimum_amount: 75.0,
  usage_limit: nil,
  used_count: 0,
  start_date: Time.current,
  end_date: 90.days.from_now,
  is_active: true,
  code: 'FREESHIP',
  applies_to: 'all'
)

# Category-specific discount
if Category.exists?
  category = Category.first
  Discount.create!(
    name: 'Electronics Sale',
    description: '15% off electronics',
    discount_type: 'percentage',
    value: 15.0,
    minimum_amount: 0.0,
    usage_limit: 200,
    used_count: 0,
    start_date: Time.current,
    end_date: 45.days.from_now,
    is_active: true,
    code: 'ELECTRONICS15',
    applies_to: 'categories',
    applies_to_ids: category.id.to_s
  )
end

# Product-specific discount
if Product.exists?
  product = Product.first
  Discount.create!(
    name: 'Featured Product',
    description: '$5 off featured product',
    discount_type: 'fixed_amount',
    value: 5.0,
    minimum_amount: 0.0,
    usage_limit: 100,
    used_count: 0,
    start_date: Time.current,
    end_date: 30.days.from_now,
    is_active: true,
    code: 'FEATURED5',
    applies_to: 'products',
    applies_to_ids: product.id.to_s
  )
end

Rails.logger.debug { "Created #{Discount.count} discounts" }

# Promotion Seeds
Rails.logger.debug 'Creating promotion seeds...'

# Bulk pricing promotion
Promotion.create!(
  name: 'Bulk Electronics Discount',
  description: 'Buy more, save more on electronics',
  promotion_type: 'bulk_pricing',
  conditions: {
    'category_ids' => [1, 2], # Assuming categories 1 and 2 are electronics
    'minimum_amount' => 100.0
  }.to_json,
  benefits: {
    'tiers' => [
      {
        'min_quantity' => 2,
        'discount_type' => 'percentage',
        'discount_value' => 5.0
      },
      {
        'min_quantity' => 5,
        'discount_type' => 'percentage',
        'discount_value' => 10.0
      },
      {
        'min_quantity' => 10,
        'discount_type' => 'percentage',
        'discount_value' => 15.0
      }
    ]
  }.to_json,
  start_date: Time.current,
  end_date: 60.days.from_now,
  is_active: true,
  usage_limit: 100,
  used_count: 0,
  priority: 'high',
  stackable: false
)

# Buy X Get Y promotion
Promotion.create!(
  name: 'Buy 2 Get 1 Free',
  description: 'Buy 2 items, get 1 free',
  promotion_type: 'buy_x_get_y',
  conditions: {
    'minimum_amount' => 50.0
  }.to_json,
  benefits: {
    'buy_quantity' => 2,
    'get_quantity' => 1
  }.to_json,
  start_date: Time.current,
  end_date: 30.days.from_now,
  is_active: true,
  usage_limit: 50,
  used_count: 0,
  priority: 'normal',
  stackable: true
)

# Free gift promotion
if Product.exists?
  gift_product = Product.last
  Promotion.create!(
    name: 'Free Gift with Purchase',
    description: 'Get a free gift with orders over $75',
    promotion_type: 'free_gift',
    conditions: {
      'minimum_amount' => 75.0
    }.to_json,
    benefits: {
      'gift_product_id' => gift_product.id,
      'gift_quantity' => 1
    }.to_json,
    start_date: Time.current,
    end_date: 45.days.from_now,
    is_active: true,
    usage_limit: 75,
    used_count: 0,
    priority: 'normal',
    stackable: false
  )
end

# Shipping discount promotion
Promotion.create!(
  name: 'Free Shipping Weekend',
  description: 'Free shipping on all orders this weekend',
  promotion_type: 'shipping_discount',
  conditions: {
    'minimum_amount' => 25.0
  }.to_json,
  benefits: {
    'free_shipping' => true
  }.to_json,
  start_date: Time.current,
  end_date: 3.days.from_now,
  is_active: true,
  usage_limit: nil,
  used_count: 0,
  priority: 'high',
  stackable: true
)

Rails.logger.debug { "Created #{Promotion.count} promotions" }
Rails.logger.debug 'Discount and Promotion seeds completed!'
