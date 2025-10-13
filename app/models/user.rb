# == Schema Information
#
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
  has_many :carts, dependent: :destroy
  has_many :notifications, dependent: :destroy

  validates :name,
            presence: true,
            length: { minimum: 2, maximum: 50 }

  validates :email,
            presence: true,
            uniqueness: { case_sensitive: false },
            format: { with: URI::MailTo::EMAIL_REGEXP },
            length: { maximum: 255 }

  validates :phone, length: { maximum: 20 }
  validates :first_name, length: { maximum: 50 }
  validates :last_name, length: { maximum: 50 }
  validates :gender, inclusion: { in: %w[male female other] }, allow_blank: true
  validates :bio, length: { maximum: 1000 }

  validates :role,
            presence: true,
            inclusion: { in: ROLES }

  validates :password,
            length: { minimum: 6 },
            allow_nil: true,
            on: :create

  # Enums
  enum :role, {
    admin: 'admin',
    customer: 'customer'
  }, default: :customer

  before_validation :set_default_role, on: :create
  before_save :downcase_email
  after_create :generate_email_verification_token

  scope :admin, -> { where(role: 'admin') }
  scope :customer, -> { where(role: 'customer') }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_name, -> { order(:name) }
  scope :verified, -> { where.not(email_verified_at: nil) }
  scope :unverified, -> { where(email_verified_at: nil) }

  def display_name
    name.presence || email.split('@').first
  end

  def admin?
    role == 'admin'
  end

  def customer?
    role == 'customer'
  end

  def email_verified?
    email_verified_at.present?
  end

  def verify_email!
    update!(email_verified_at: Time.current, email_verification_token: nil)
  end

  def generate_email_verification_token!
    token = SecureRandom.urlsafe_base64(32)
    update!(email_verification_token: token)
    token
  end

  def self.authenticate(email, password)
    user = find_by(email: email.downcase)
    user&.authenticate(password)
  end

  def self.find_by_email(email)
    find_by(email: email.downcase)
  end

  def self.find_by_verification_token(token)
    find_by(email_verification_token: token)
  end

  private

  def set_default_role
    self.role ||= 'customer'
  end

  def downcase_email
    self.email = email.downcase if email.present?
  end

  def generate_email_verification_token
    self.email_verification_token = SecureRandom.urlsafe_base64(32)
    save!
  end

  # def password_complexity
  #   return if password.blank?

  #   return if password.match?(/\A(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/)

  #   errors.add(:password, 'must include at least one lowercase letter, one uppercase letter, and one digit')
  # end

  # Profile methods
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

  def profile_complete?
    first_name.present? && last_name.present? && phone.present?
  end

  def profile_completion_percentage
    fields = %w[first_name last_name phone date_of_birth gender bio]
    completed_fields = fields.count { |field| send(field).present? }
    (completed_fields.to_f / fields.size * 100).round
  end

  # Address methods
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

  # Notification preferences
  def notification_preferences
    preferences['notifications'] || {}
  end

  def update_notification_preferences(new_preferences)
    current_preferences = preferences || {}
    current_preferences['notifications'] = new_preferences
    update!(preferences: current_preferences)
  end

  def email_notifications_enabled?
    notification_preferences['email'] != false
  end

  def push_notifications_enabled?
    notification_preferences['push'] != false
  end

  def sms_notifications_enabled?
    notification_preferences['sms'] == true
  end

end
