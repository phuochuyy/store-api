class User < ApplicationRecord
  has_secure_password

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, presence: true, inclusion: { in: %w[admin customer] }

  enum :role, {
    admin: "admin",
    customer: "customer"
  }

  def generate_jwt
    JWT.encode(
      {
        user_id: id,
        email: email,
        role: role,
        exp: 24.hours.from_now.to_i
      },
      Rails.application.credentials.secret_key_base
    )
  end

  def self.decode_jwt(token)
    JWT.decode(token, Rails.application.credentials.secret_key_base)[0]
  rescue JWT::DecodeError
    nil
  end
end
