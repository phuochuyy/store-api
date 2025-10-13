# == Schema Information
#
# Table name: carts
#
#  id           :integer          not null, primary key
#  user_id      :integer
#  session_id   :string(255)      not null
#  status       :string(255)      default("active")
#  total_amount :decimal(10, 2)   default(0.0)
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#

class Cart < ApplicationRecord
  belongs_to :user, optional: true
  has_many :cart_items, dependent: :destroy
  has_many :products, through: :cart_items

  validates :session_id, presence: true
  validates :status, presence: true, inclusion: { in: %w[active abandoned completed] }
  validates :total_amount, numericality: { greater_than_or_equal_to: 0 }

  enum :status, {
    active: 'active',
    abandoned: 'abandoned',
    completed: 'completed'
  }

  scope :active, -> { where(status: 'active') }
  scope :for_user, ->(user) { where(user: user) }
  scope :for_session, ->(session_id) { where(session_id: session_id) }

  def total_items
    cart_items.sum(:quantity)
  end

  def calculate_total_amount
    total = cart_items.sum { |item| item.quantity * item.unit_price }
    update!(total_amount: total)
    total
  end

  def add_product(product, quantity = 1)
    cart_item = cart_items.find_by(product: product)

    if cart_item
      cart_item.increment(:quantity, quantity)
      cart_item.save!
    else
      cart_items.create!(
        product: product,
        quantity: quantity,
        unit_price: product.price
      )
    end

    calculate_total_amount
  end

  def remove_product?(product)
    cart_item = cart_items.find_by(product: product)
    return false unless cart_item

    cart_item.destroy
    calculate_total_amount
    true
  end

  def update_product_quantity?(product, quantity)
    cart_item = cart_items.find_by(product: product)
    return false unless cart_item

    if quantity <= 0
      cart_item.destroy
    else
      cart_item.update!(quantity: quantity)
    end

    calculate_total_amount
    true
  end

  def clear
    cart_items.destroy_all
    update!(total_amount: 0.0)
  end

  delegate :empty?, to: :cart_items

  def self.find_or_create_for_user(user)
    find_or_create_by(user: user, status: 'active') do |cart|
      cart.session_id = SecureRandom.uuid
    end
  end

  def self.find_or_create_for_session(session_id)
    find_or_create_by(session_id: session_id, status: 'active') do |cart|
      cart.session_id = session_id
    end
  end
end
