class UserAddress < ApplicationRecord
  belongs_to :user

  validates :full_name, presence: true
  validates :address_line1, presence: true
  validates :city, presence: true
  validates :postal_code, presence: true
  validates :country, presence: true
  validates :address_type, inclusion: { in: %w[shipping billing] }

  # Set this address as default for its type
  def set_as_default!
    transaction do
      # Unset other default addresses of the same type
      user.user_addresses
          .where(address_type: address_type)
          .where.not(id: id)
          .update_all(is_default: false)

      # Set this address as default
      update!(is_default: true)
    end
  end
end
