require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'basic functionality' do
    it 'creates a valid user' do
      user = build(:user)
      expect(user).to be_valid
    end

    it 'requires name' do
      user = build(:user, name: nil)
      expect(user).not_to be_valid
      expect(user.errors[:name]).to include("can't be blank")
    end

    it 'requires email' do
      user = build(:user, email: nil)
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("can't be blank")
    end

    it 'validates email format' do
      user = build(:user, email: 'invalid-email')
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include('is invalid')
    end

    it 'accepts valid email format' do
      user = build(:user, email: 'valid@example.com')
      expect(user).to be_valid
    end

    it 'requires password on create' do
      user = build(:user, password: nil)
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include("can't be blank")
    end

    it 'validates password length' do
      user = build(:user, password: '123')
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include('is too short (minimum is 6 characters)')
    end

    it 'sets default role to customer' do
      user = build(:user, role: nil)
      user.valid?
      expect(user.role).to eq('customer')
    end

    it 'downcases email before saving' do
      user = create(:user, email: 'TEST@EXAMPLE.COM')
      expect(user.email).to eq('test@example.com')
    end
  end

  describe 'associations' do
    let(:user) { create(:user) }

    it 'has many carts' do
      expect(user).to respond_to(:carts)
    end

    it 'has many notifications' do
      expect(user).to respond_to(:notifications)
    end
  end

  describe 'enums' do
    it 'defines role enum' do
      expect(User.roles).to eq({ 'admin' => 'admin', 'customer' => 'customer' })
    end

    it 'has admin? method' do
      admin_user = create(:user, :admin)
      expect(admin_user.admin?).to be true
    end

    it 'has customer? method' do
      customer_user = create(:user, :customer)
      expect(customer_user.customer?).to be true
    end
  end

  describe 'scopes' do
    let!(:admin_user) { create(:user, :admin) }
    let!(:customer_user) { create(:user, :customer) }

    it 'filters admin users' do
      expect(User.admin).to include(admin_user)
      expect(User.admin).not_to include(customer_user)
    end

    it 'filters customer users' do
      expect(User.customer).to include(customer_user)
      expect(User.customer).not_to include(admin_user)
    end
  end

  describe 'authentication' do
    it 'authenticates with correct credentials' do
      user = User.create!(name: 'Auth Test', email: 'auth@example.com', password: 'password123')
      authenticated_user = User.authenticate('auth@example.com', 'password123')
      expect(authenticated_user).to eq(user)
    end

    it 'returns nil with incorrect email' do
      User.create!(name: 'Auth Test', email: 'auth@example.com', password: 'password123')
      authenticated_user = User.authenticate('wrong@example.com', 'password123')
      expect(authenticated_user).to be_nil
    end

    it 'returns false with incorrect password' do
      User.create!(name: 'Auth Test', email: 'auth@example.com', password: 'password123')
      authenticated_user = User.authenticate('auth@example.com', 'wrongpassword')
      expect(authenticated_user).to be false
    end
  end

  describe 'email verification' do
    let(:user) { create(:user) }

    it 'generates verification token on create' do
      expect(user.email_verification_token).to be_present
    end

    it 'verifies email' do
      user.verify_email!
      expect(user.email_verified_at).to be_present
      expect(user.email_verification_token).to be_nil
    end

    it 'checks if email is verified' do
      expect(user.email_verified?).to be false
      user.verify_email!
      expect(user.email_verified?).to be true
    end
  end

  describe 'display name' do
    it 'returns name when present' do
      user = create(:user, name: 'John Doe')
      expect(user.display_name).to eq('John Doe')
    end

    it 'returns email prefix when name is not present' do
      user = User.create!(name: 'Test User', email: 'display@example.com', password: 'password123')
      user.update_column(:name, nil) # Skip validations to test display_name
      expect(user.display_name).to eq('display')
    end
  end

  describe 'database constraints' do
    it 'prevents duplicate emails' do
      User.create!(name: 'User 1', email: 'duplicate@example.com', password: 'password123')
      expect do
        User.create!(name: 'User 2', email: 'duplicate@example.com', password: 'password123')
      end.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'prevents same email with different case' do
      User.create!(name: 'User 1', email: 'case@example.com', password: 'password123')
      expect do
        User.create!(name: 'User 2', email: 'CASE@EXAMPLE.COM', password: 'password123')
      end.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe 'class methods' do
    let!(:user) { create(:user, email: 'find@example.com') }

    it 'finds user by email' do
      found_user = User.find_by(email: 'find@example.com')
      expect(found_user).to eq(user)
    end

    it 'finds user by email case insensitive' do
      found_user = User.where('LOWER(email) = ?', 'FIND@EXAMPLE.COM'.downcase).first
      expect(found_user).to eq(user)
    end

    it 'returns nil when user not found' do
      found_user = User.find_by(email: 'nonexistent@example.com')
      expect(found_user).to be_nil
    end
  end

  describe 'password security' do
    it 'has secure password functionality' do
      user = create(:user, password: 'password123')
      expect(user.authenticate('password123')).to eq(user)
      expect(user.authenticate('wrongpassword')).to be false
    end

    it 'stores password digest, not plain password' do
      user = create(:user, password: 'password123')
      expect(user.password_digest).to be_present
      expect(user.password_digest).not_to eq('password123')
    end
  end

end
