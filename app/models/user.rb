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
  has_secure_password

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, presence: true, inclusion: { in: %w[admin customer] }

  enum :role, {
    admin: "admin",
    customer: "customer"
  }

  # Simple authentication method for demo
  def self.authenticate(email, password)
    user = find_by(email: email)
    user&.authenticate(password)
  end
end
