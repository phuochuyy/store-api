class UserValidator
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :name, :string
  attribute :email, :string
  attribute :password, :string
  attribute :password_confirmation, :string
  attribute :role, :string

  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, presence: true, length: { minimum: 6 }
  validates :password_confirmation, presence: true
  validates :role, inclusion: { in: %w[admin customer] }

  validate :passwords_match

  private

  def passwords_match
    return unless password.present? && password_confirmation.present?
    
    unless password == password_confirmation
      errors.add(:password_confirmation, "doesn't match Password")
    end
  end
end
