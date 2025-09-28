require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    it 'validates presence of name' do
      user = User.new(email: 'test@example.com', password: 'password')
      expect(user).not_to be_valid
      expect(user.errors[:name]).to include("can't be blank")
    end

    it 'validates presence of email' do
      user = User.new(name: 'Test User', password: 'password')
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("can't be blank")
    end

    it 'validates presence of role' do
      user = User.new(name: 'Test User', email: 'test@example.com', password: 'password')
      expect(user).to be_valid # role has default value
    end

    it 'validates length of name' do
      user = User.new(name: 'A', email: 'test@example.com', password: 'password')
      expect(user).not_to be_valid
      expect(user.errors[:name]).to include('is too short (minimum is 2 characters)')
    end

    it 'validates length of password' do
      user = User.new(name: 'Test User', email: 'test@example.com', password: '12345')
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include('is too short (minimum is 6 characters)')
    end

    it 'validates inclusion of role' do
      user = User.new(name: 'Test User', email: 'test@example.com', password: 'password', role: 'invalid')
      expect(user).not_to be_valid
      expect(user.errors[:role]).to include('is not included in the list')
    end
  end

  describe 'associations' do
    # Add associations if any
  end

  describe 'enums' do
    it 'defines role enum correctly' do
      expect(User.roles).to eq({ 'admin' => 'admin', 'customer' => 'customer' })
    end
  end

  describe 'scopes' do
    let!(:admin_user) { create(:user, role: 'admin') }
    let!(:customer_user) { create(:user, role: 'customer') }
    let!(:verified_user) { create(:user, email_verified_at: Time.current) }
    let!(:unverified_user) { create(:user, email_verified_at: nil) }

    it 'returns admin users' do
      expect(User.admin).to include(admin_user)
      expect(User.admin).not_to include(customer_user)
    end

    it 'returns customer users' do
      expect(User.customer).to include(customer_user)
      expect(User.customer).not_to include(admin_user)
    end

    it 'returns verified users' do
      expect(User.verified).to include(verified_user)
      expect(User.verified).not_to include(unverified_user)
    end

    it 'returns unverified users' do
      expect(User.unverified).to include(unverified_user)
      expect(User.unverified).not_to include(verified_user)
    end
  end

  describe 'email verification' do
    let(:user) { create(:user) }

    describe '#email_verified?' do
      it 'returns true when email is verified' do
        user.update!(email_verified_at: Time.current)
        expect(user.email_verified?).to be true
      end

      it 'returns false when email is not verified' do
        expect(user.email_verified?).to be false
      end
    end

    describe '#verify_email!' do
      it 'sets email_verified_at and clears token' do
        user.update!(email_verification_token: 'some_token')

        expect do
          user.verify_email!
        end.to change { user.email_verified_at }.from(nil)
                                                .and change { user.email_verification_token }.to(nil)
      end
    end

    describe '#generate_email_verification_token!' do
      it 'generates a new token and returns it' do
        token = user.generate_email_verification_token!

        expect(token).to be_present
        expect(user.email_verification_token).to eq(token)
      end
    end

    describe '.find_by_verification_token' do
      let(:user_with_token) { create(:user, email_verification_token: 'test_token') }

      it 'finds user by verification token' do
        expect(User.find_by_verification_token('test_token')).to eq(user_with_token)
      end

      it 'returns nil for invalid token' do
        expect(User.find_by_verification_token('invalid_token')).to be_nil
      end
    end
  end

  describe 'callbacks' do
    it 'generates email verification token after create' do
      user = build(:user)
      expect(user).to receive(:generate_email_verification_token)
      user.save!
    end

    it 'downcases email before save' do
      user = create(:user, email: 'TEST@EXAMPLE.COM')
      expect(user.email).to eq('test@example.com')
    end

    it 'sets default role to customer' do
      user = create(:user, role: nil)
      expect(user.role).to eq('customer')
    end
  end

  describe 'authentication' do
    let(:user) { create(:user, email: 'test@example.com', password: 'password123') }

    describe '.authenticate' do
      it 'authenticates with correct credentials' do
        expect(User.authenticate('test@example.com', 'password123')).to eq(user)
      end

      it 'returns nil with incorrect password' do
        expect(User.authenticate('test@example.com', 'wrong_password')).to be_nil
      end

      it 'returns nil with non-existent email' do
        expect(User.authenticate('nonexistent@example.com', 'password123')).to be_nil
      end
    end

    describe '.find_by_email' do
      it 'finds user by email (case insensitive)' do
        expect(User.find_by_email('TEST@EXAMPLE.COM')).to eq(user)
      end
    end
  end
end
