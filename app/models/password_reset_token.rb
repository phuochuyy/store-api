class PasswordResetToken < ApplicationRecord
  belongs_to :user

  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :active, -> { where(used: false).where('expires_at > ?', Time.current) }

  def self.generate_for_user(user, ip_address: nil, user_agent: nil)
    token = SecureRandom.urlsafe_base64(32)
    expires_at = 1.hour.from_now

    create!(
      user: user,
      token: token,
      expires_at: expires_at,
      ip_address: ip_address,
      user_agent: user_agent
    )
  end

  def expired?
    expires_at <= Time.current
  end

  def used?
    used
  end

  def active?
    !expired? && !used?
  end
end
