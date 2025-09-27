require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      user = build(:user)
      expect(user).to be_valid
    end

    it 'is invalid without a name' do
      user = build(:user, name: nil)
      expect(user).not_to be_valid
      expect(user.errors[:name]).to include("can't be blank")
    end

    it 'is invalid without an email' do
      user = build(:user, email: nil)
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("can't be blank")
    end

    it 'is invalid with duplicate email' do
      create(:user, email: 'test@example.com')
      user = build(:user, email: 'test@example.com')
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include('has already been taken')
    end

    it 'is invalid with invalid email format' do
      user = build(:user, email: 'invalid-email')
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include('is invalid')
    end

    it 'is invalid without a role' do
      user = build(:user, role: nil)
      expect(user).not_to be_valid
      expect(user.errors[:role]).to include("can't be blank")
    end

    it 'is invalid with invalid role' do
      expect { build(:user, role: 'invalid_role') }.to raise_error(ArgumentError)
    end

    it 'is valid with admin role' do
      user = build(:user, role: 'admin')
      expect(user).to be_valid
    end

    it 'is valid with customer role' do
      user = build(:user, role: 'customer')
      expect(user).to be_valid
    end
  end

  describe 'password' do
    it 'requires password on creation' do
      user = build(:user, password: nil, password_confirmation: nil)
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include("can't be blank")
    end

    it 'validates password confirmation' do
      user = build(:user, password: 'password123', password_confirmation: 'different')
      expect(user).not_to be_valid
      expect(user.errors[:password_confirmation]).to include("doesn't match Password")
    end

    it 'encrypts password' do
      user = create(:user, password: 'password', password_confirmation: 'password')
      expect(user.password_digest).not_to eq('password')
      expect(user.password_digest).to be_present
    end
  end

  describe 'authentication' do
    let(:user) { create(:user, email: 'test@example.com', password: 'password', password_confirmation: 'password') }

    it 'authenticates with correct password' do
      expect(user.authenticate('password')).to eq(user)
    end

    it 'does not authenticate with incorrect password' do
      expect(user.authenticate('wrongpassword')).to be_falsey
    end

    it 'finds and authenticates user by email and password' do
      authenticated_user = User.authenticate(user.email, 'password')
      expect(authenticated_user).to eq(user)
    end

    it 'returns nil for non-existent email' do
      authenticated_user = User.authenticate('nonexistent@example.com', 'password')
      expect(authenticated_user).to be_nil
    end

    it 'returns nil for wrong password' do
      authenticated_user = User.authenticate(user.email, 'wrongpassword')
      expect(authenticated_user).to be_falsey
    end
  end

  describe 'role methods' do
    let(:admin_user) { create(:user, role: 'admin') }
    let(:customer_user) { create(:user, role: 'customer') }

    it 'returns true for admin? when user is admin' do
      expect(admin_user.admin?).to be true
    end

    it 'returns false for admin? when user is customer' do
      expect(customer_user.admin?).to be false
    end

    it 'returns true for customer? when user is customer' do
      expect(customer_user.customer?).to be true
    end

    it 'returns false for customer? when user is admin' do
      expect(admin_user.customer?).to be false
    end
  end

  describe 'associations' do
    it 'has secure password' do
      expect(User.new).to respond_to(:password_digest)
      expect(User.new).to respond_to(:authenticate)
    end
  end

  describe 'enums' do
    it 'defines role enum correctly' do
      expect(User.roles).to eq({ 'admin' => 'admin', 'customer' => 'customer' })
    end
  end
end
