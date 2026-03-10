# Table name: users
#
#  id              :integer          not null, primary key
#  name            :string(255)
#  email           :string(255)
#  password_digest :string(255)
#  role            :string(255)
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#

class User < ApplicationRecord
  ROLES = %w[admin customer].freeze

  has_secure_password

  # Associations
  has_many :carts, dependent: :destroy

  # Current active cart for the user (used by Shipping, Tax controllers)
  def cart
    Cart.find_or_create_for_user(self)
  end

  has_many :notifications, dependent: :destroy
  has_many :user_addresses, dependent: :destroy
  has_many :password_reset_tokens, dependent: :destroy
  has_many :orders, dependent: :destroy
  has_many :return_requests, dependent: :destroy
  has_many :coupons, dependent: :nullify
  has_many :product_reviews, dependent: :destroy
  has_many :product_wishlists, dependent: :destroy
  has_many :product_comparisons, dependent: :destroy
  has_many :stock_movements, dependent: :destroy

  # Validations
  validates :name,
            presence: true,
            length: { minimum: 2, maximum: 50 }

  validates :email,
            presence: true,
            uniqueness: { case_sensitive: false },
            format: { with: URI::MailTo::EMAIL_REGEXP },
            length: { maximum: 255 }

  validates :phone, length: { maximum: 20 }, format: { with: /\A\+?[\d\s\-()]+\z/ }, allow_blank: true
  validates :first_name, length: { maximum: 50 }, presence: true
  validates :last_name, length: { maximum: 50 }, presence: true
  validates :gender, inclusion: { in: %w[male female other] }, allow_blank: true
  validates :bio, length: { maximum: 1000 }, allow_blank: true

  validates :password,
            length: { minimum: 6 },
            allow_nil: true,
            on: :create

  # Enums
  enum :role, {
    admin: 'admin',
    customer: 'customer'
  }, default: :customer

  # Callbacks
  before_save :downcase_email
  after_create :generate_email_verification_token
  after_commit :invalidate_jwt_cache, on: %i[update destroy]

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_name, -> { order(:name) }
  scope :verified, -> { where.not(email_verified_at: nil) }
  scope :unverified, -> { where(email_verified_at: nil) }

  # Public instance methods

  # Display name: prefers full_name, then name, then the part before @ of email.
  def display_name
    full_name.presence || name.presence || email.split('@').first
  end

  # Whether the user has verified their email (has email_verified_at).
  def email_verified?
    email_verified_at.present?
  end

  # Mark email as verified and clear email_verification_token.
  def verify_email!
    update!(email_verified_at: Time.current, email_verification_token: nil)
  end

  # Generate a new email verification token, persist to DB and return it (for use in verification link).
  def generate_email_verification_token!
    token = SecureRandom.urlsafe_base64(32)
    update!(email_verification_token: token)
    token
  end

  # Full name from first_name + last_name.
  def full_name
    [first_name, last_name].compact.join(' ')
  end

  def age
    return nil unless date_of_birth

    today = Date.current
    age = today.year - date_of_birth.year
    age -= 1 if today < date_of_birth + age.years
    age
  end

  # Whether the profile has required fields (first_name, last_name, phone).
  def profile_complete?
    first_name.present? && last_name.present? && phone.present?
  end

  # Profile completion percentage based on first_name, last_name, phone, date_of_birth, gender, bio.
  def profile_completion_percentage
    fields = %w[first_name last_name phone date_of_birth gender bio]
    completed_fields = fields.count do |field|
      respond_to?(field) && send(field).present?
    end
    (completed_fields.to_f / fields.size * 100).round
  end

  # Default address for the given type (shipping/billing).
  def default_address(address_type = 'shipping')
    user_addresses.find_by(address_type: address_type, is_default: true)
  end

  def address?(address_type = 'shipping')
    user_addresses.exists?(address_type: address_type)
  end

  def address_count
    user_addresses.count
  end

  # Password reset methods
  def generate_password_reset_token(ip_address: nil, user_agent: nil)
    PasswordResetToken.generate_for_user(self, ip_address: ip_address, user_agent: user_agent)
  end

  def active_password_reset_tokens
    password_reset_tokens.active
  end

  def active_password_reset_token?
    active_password_reset_tokens.exists?
  end

  # Notification preferences methods
  def notification_preferences
    @notification_preferences ||= preferences['notifications'] || {}
  end

  def update_notification_preferences?(new_preferences)
    return false unless new_preferences.is_a?(Hash)

    current_preferences = preferences || {}
    current_preferences['notifications'] = new_preferences
    update!(preferences: current_preferences)
    @notification_preferences = nil # Clear cache
    true
  end

  def email_notifications_enabled?
    notification_preferences['email'] == true
  end

  def push_notifications_enabled?
    notification_preferences['push'] == true
  end

  def sms_notifications_enabled?
    notification_preferences['sms'] == true
  end

  # Class methods

  # Authenticate user by email (case-insensitive) and password; returns user or nil.
  def self.authenticate(email, password)
    user = find_by(email: email.downcase)
    user&.authenticate(password)
  end

  # Find user by email (normalized to lowercase).
  def self.find_by_email(email)
    find_by(email: email.downcase)
  end

  # Find user by email verification token (used in verify_email flow).
  def self.find_by_verification_token(token)
    return nil if token.blank?

    find_by(email_verification_token: token)
  end

  private

  # Normalize email before save: always lowercase.
  def downcase_email
    self.email = email.downcase if email.present?
  end

  # Callback after_create: generate email verification token for new user.
  def generate_email_verification_token
    self.email_verification_token = SecureRandom.urlsafe_base64(32)
    update!(email_verification_token: email_verification_token)
  rescue StandardError => e
    Rails.logger.error "Failed to generate email verification token: #{e.message}"
  end

  # Callback after_commit (update/destroy): invalidate user JWT cache so tokens reflect fresh data.
  def invalidate_jwt_cache
    Auth::Jwt::CacheService.invalidate_user(id) if id.present?
  rescue StandardError => e
    Rails.logger.error "Failed to invalidate JWT cache: #{e.message}"
  end
end
