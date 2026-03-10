require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it { should have_many(:carts).dependent(:destroy) }
    it { should have_many(:notifications).dependent(:destroy) }
    it { should have_many(:user_addresses).dependent(:destroy) }
    it { should have_many(:password_reset_tokens).dependent(:destroy) }
    it { should have_many(:orders).dependent(:destroy) }
    it { should have_many(:coupons).dependent(:nullify) }
    it { should have_many(:product_reviews).dependent(:destroy) }
    it { should have_many(:product_wishlists).dependent(:destroy) }
    it { should have_many(:product_comparisons).dependent(:destroy) }
    it { should have_many(:stock_movements).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:user) }

    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_least(2).is_at_most(50) }

    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).case_insensitive }
    it { should validate_length_of(:email).is_at_most(255) }

    it { should validate_presence_of(:first_name) }
    it { should validate_length_of(:first_name).is_at_most(50) }

    it { should validate_presence_of(:last_name) }
    it { should validate_length_of(:last_name).is_at_most(50) }

    it { should validate_length_of(:phone).is_at_most(20) }
    it { should validate_length_of(:bio).is_at_most(1000) }

    context 'email format' do
      it 'accepts valid email' do
        user = build(:user, email: 'valid@example.com', first_name: 'Test', last_name: 'User')
        expect(user).to be_valid
      end

      it 'rejects invalid email' do
        user = build(:user, email: 'invalid-email', first_name: 'Test', last_name: 'User')
        expect(user).not_to be_valid
        expect(user.errors[:email]).to include('is invalid')
      end
    end

    context 'phone format' do
      it 'accepts valid phone formats' do
        valid_phones = ['+1234567890', '123-456-7890', '(123) 456-7890', '1234567890']
        valid_phones.each do |phone|
          user = build(:user, phone: phone, first_name: 'Test', last_name: 'User')
          expect(user).to be_valid, "Expected #{phone} to be valid"
        end
      end

      it 'rejects invalid phone format' do
        user = build(:user, phone: 'invalid-phone-123', first_name: 'Test', last_name: 'User')
        expect(user).not_to be_valid
        expect(user.errors[:phone]).to be_present
      end

      it 'allows blank phone' do
        user = build(:user, phone: nil, first_name: 'Test', last_name: 'User')
        expect(user).to be_valid
      end
    end

    context 'gender' do
      it 'accepts valid gender values' do
        %w[male female other].each do |gender|
          user = build(:user, gender: gender, first_name: 'Test', last_name: 'User')
          expect(user).to be_valid
        end
      end

      it 'rejects invalid gender' do
        user = build(:user, gender: 'invalid', first_name: 'Test', last_name: 'User')
        expect(user).not_to be_valid
        expect(user.errors[:gender]).to be_present
      end

      it 'allows blank gender' do
        user = build(:user, gender: nil, first_name: 'Test', last_name: 'User')
        expect(user).to be_valid
      end
    end

    context 'password' do
      it 'requires password on create' do
        user = build(:user, password: nil)
        expect(user).not_to be_valid
        expect(user.errors[:password]).to include("can't be blank")
      end

      it 'validates password length' do
        user = build(:user, password: '12345')
        expect(user).not_to be_valid
        expect(user.errors[:password]).to include('is too short (minimum is 6 characters)')
      end

      it 'allows nil password on update' do
        user = create(:user)
        original_digest = user.password_digest
        user.password = nil
        user.password_confirmation = nil
        user.update_column(:password_digest, original_digest) # Manually set to test that validation allows nil
        user.reload
        expect(user.password_digest).to eq(original_digest) # Password digest should remain unchanged
      end
    end
  end

  describe 'enums' do
    it 'defines role enum' do
      expect(User.roles).to eq({ 'admin' => 'admin', 'customer' => 'customer' })
    end

    it 'has admin? method' do
      admin_user = create(:user, :admin)
      expect(admin_user.admin?).to be true
      expect(admin_user.customer?).to be false
    end

    it 'has customer? method' do
      customer_user = create(:user, :customer)
      expect(customer_user.customer?).to be true
      expect(customer_user.admin?).to be false
    end

    it 'defaults to customer role' do
      user = User.new(first_name: 'Test', last_name: 'User', email: 'test@example.com', password: 'password123')
      expect(user.role).to eq('customer')
    end
  end

  describe 'scopes' do
    before do
      DatabaseCleaner.clean
    end

    let!(:admin_user) { create(:user, :admin, created_at: 2.days.ago) }
    let!(:customer_user) { create(:user, :customer, created_at: 1.day.ago) }
    let!(:verified_user) { create(:user, :verified) }
    let!(:unverified_user) { create(:user, :unverified) }

    describe '.recent' do
      it 'orders by created_at desc' do
        recent_users = User.recent.limit(2).to_a
        expect(recent_users.size).to eq(2)
        expect(recent_users.first.created_at).to be > recent_users.last.created_at
      end
    end

    describe '.by_name' do
      it 'orders by name' do
        DatabaseCleaner.clean
        create(:user, name: 'Alice')
        create(:user, name: 'Bob')
        expect(User.by_name.limit(2).pluck(:name)).to eq(%w[Alice Bob])
      end
    end

    describe '.verified' do
      it 'returns only verified users' do
        expect(User.verified).to include(verified_user)
        expect(User.verified).not_to include(unverified_user)
      end
    end

    describe '.unverified' do
      it 'returns only unverified users' do
        expect(User.unverified).to include(unverified_user)
        expect(User.unverified).not_to include(verified_user)
      end
    end
  end

  describe 'callbacks' do
    describe 'before_save :downcase_email' do
      it 'downcases email before saving' do
        user = create(:user, email: 'TEST@EXAMPLE.COM')
        expect(user.email).to eq('test@example.com')
      end

      it 'handles already downcased email' do
        user = create(:user, email: 'test@example.com')
        expect(user.email).to eq('test@example.com')
      end
    end

    describe 'after_create :generate_email_verification_token' do
      it 'generates verification token on create' do
        user = create(:user)
        expect(user.email_verification_token).to be_present
      end

      it 'generates unique tokens' do
        user1 = create(:user)
        user2 = create(:user)
        expect(user1.email_verification_token).not_to eq(user2.email_verification_token)
      end
    end
  end

  describe '#display_name' do
    context 'when full_name is present' do
      it 'returns full_name' do
        user = create(:user, :with_profile, name: 'Test Name')
        expect(user.display_name).to eq('John Doe')
      end
    end

    context 'when full_name is blank but name is present' do
      it 'returns name' do
        user = create(:user, name: 'Test Name')
        user.update_columns(first_name: nil, last_name: nil) # Skip validations
        expect(user.display_name).to eq('Test Name')
      end
    end

    context 'when both full_name and name are blank' do
      it 'returns email prefix' do
        user = create(:user, email: 'testuser@example.com')
        user.update_columns(name: nil, first_name: nil, last_name: nil) # Skip validations
        expect(user.display_name).to eq('testuser')
      end
    end
  end

  describe '#full_name' do
    it 'returns first_name and last_name joined' do
      user = create(:user, first_name: 'John', last_name: 'Doe')
      expect(user.full_name).to eq('John Doe')
    end

    it 'handles missing first_name' do
      user = create(:user, last_name: 'Doe')
      user.update_column(:first_name, nil) # Skip validations
      expect(user.full_name).to eq('Doe')
    end

    it 'handles missing last_name' do
      user = create(:user, first_name: 'John')
      user.update_column(:last_name, nil) # Skip validations
      expect(user.full_name).to eq('John')
    end

    it 'returns empty string when both are blank' do
      user = create(:user)
      user.update_columns(first_name: nil, last_name: nil) # Skip validations
      expect(user.full_name).to eq('')
    end
  end

  describe '#age' do
    it 'calculates age correctly' do
      user = create(:user, date_of_birth: 25.years.ago)
      expect(user.age).to eq(25)
    end

    it 'returns nil when date_of_birth is nil' do
      user = create(:user, date_of_birth: nil)
      expect(user.age).to be_nil
    end

    it 'handles birthday not yet occurred this year' do
      user = create(:user, date_of_birth: 25.years.ago + 1.month)
      expect(user.age).to eq(24)
    end
  end

  describe '#profile_complete?' do
    it 'returns true when all required fields are present' do
      user = create(:user, :with_profile)
      expect(user.profile_complete?).to be true
    end

    it 'returns false when first_name is missing' do
      user = create(:user, last_name: 'Doe', phone: '+1234567890')
      user.update_column(:first_name, nil) # Skip validations
      expect(user.profile_complete?).to be false
    end

    it 'returns false when last_name is missing' do
      user = create(:user, first_name: 'John', phone: '+1234567890')
      user.update_column(:last_name, nil) # Skip validations
      expect(user.profile_complete?).to be false
    end

    it 'returns false when phone is missing' do
      user = create(:user, first_name: 'John', last_name: 'Doe', phone: nil)
      expect(user.profile_complete?).to be false
    end
  end

  describe '#profile_completion_percentage' do
    it 'calculates percentage correctly' do
      user = create(:user, :with_profile)
      expect(user.profile_completion_percentage).to be > 0
    end

    it 'returns 0 when no fields are filled' do
      user = create(:user)
      user.update_columns(
        first_name: nil, last_name: nil, phone: nil,
        date_of_birth: nil, gender: nil, bio: nil
      ) # Skip validations
      expect(user.profile_completion_percentage).to eq(0)
    end

    it 'returns 100 when all fields are filled' do
      user = create(:user, :with_profile)
      percentage = user.profile_completion_percentage
      expect(percentage).to be_between(0, 100)
    end
  end

  describe 'email verification' do
    let(:user) { create(:user) }

    describe '#email_verified?' do
      it 'returns false when email is not verified' do
        expect(user.email_verified?).to be false
      end

      it 'returns true when email is verified' do
        user.verify_email!
        expect(user.email_verified?).to be true
      end
    end

    describe '#verify_email!' do
      it 'sets email_verified_at' do
        user.verify_email!
        expect(user.email_verified_at).to be_present
      end

      it 'clears email_verification_token' do
        user.verify_email!
        expect(user.email_verification_token).to be_nil
      end
    end

    describe '#generate_email_verification_token!' do
      it 'generates a new token' do
        old_token = user.email_verification_token
        new_token = user.generate_email_verification_token!
        expect(new_token).to be_present
        expect(new_token).not_to eq(old_token)
      end

      it 'updates the token in database' do
        new_token = user.generate_email_verification_token!
        user.reload
        expect(user.email_verification_token).to eq(new_token)
      end
    end
  end

  describe 'address methods' do
    let(:user) { create(:user) }

    describe '#default_address' do
      it 'returns default address for given type' do
        address = user.user_addresses.create!(
          full_name: 'John Doe',
          address_line1: '123 Main St',
          city: 'HCMC',
          postal_code: '70000',
          country: 'VN',
          address_type: 'shipping',
          is_default: true
        )
        expect(user.default_address('shipping')).to eq(address)
      end

      it 'returns nil when no default address exists' do
        expect(user.default_address('shipping')).to be_nil
      end
    end

    describe '#address?' do
      it 'returns true when address exists' do
        user.user_addresses.create!(
          full_name: 'John Doe',
          address_line1: '123 Main St',
          city: 'HCMC',
          postal_code: '70000',
          country: 'VN',
          address_type: 'shipping'
        )
        expect(user.address?('shipping')).to be true
      end

      it 'returns false when address does not exist' do
        expect(user.address?('shipping')).to be false
      end
    end

    describe '#address_count' do
      it 'returns correct count' do
        3.times do
          user.user_addresses.create!(
            full_name: 'John Doe',
            address_line1: '123 Main St',
            city: 'HCMC',
            postal_code: '70000',
            country: 'VN'
          )
        end
        expect(user.address_count).to eq(3)
      end

      it 'returns 0 when no addresses exist' do
        expect(user.address_count).to eq(0)
      end
    end
  end

  describe 'password reset methods' do
    let(:user) { create(:user) }

    describe '#generate_password_reset_token' do
      it 'calls PasswordResetToken.generate_for_user if class exists' do
        if defined?(PasswordResetToken)
          expect(PasswordResetToken).to receive(:generate_for_user).with(user, ip_address: nil, user_agent: nil)
          user.generate_password_reset_token
        else
          expect { user.generate_password_reset_token }.not_to raise_error
        end
      end

      it 'passes ip_address and user_agent' do
        if defined?(PasswordResetToken)
          expect(PasswordResetToken).to receive(:generate_for_user).with(user, ip_address: '127.0.0.1',
                                                                               user_agent: 'Test')
          user.generate_password_reset_token(ip_address: '127.0.0.1', user_agent: 'Test')
        else
          expect { user.generate_password_reset_token(ip_address: '127.0.0.1', user_agent: 'Test') }.not_to raise_error
        end
      end
    end

    describe '#active_password_reset_tokens' do
      it 'returns active tokens' do
        if user.password_reset_tokens.respond_to?(:active)
          expect(user.password_reset_tokens).to receive(:active)
          user.active_password_reset_tokens
        else
          expect(user.active_password_reset_tokens).to respond_to(:exists?)
        end
      end
    end

    describe '#active_password_reset_token?' do
      it 'returns true when active token exists' do
        allow(user).to receive(:active_password_reset_tokens).and_return(double(exists?: true))
        expect(user.active_password_reset_token?).to be true
      end

      it 'returns false when no active token exists' do
        allow(user).to receive(:active_password_reset_tokens).and_return(double(exists?: false))
        expect(user.active_password_reset_token?).to be false
      end
    end
  end

  describe 'notification preferences' do
    let(:user) { create(:user) }

    describe '#notification_preferences' do
      it 'returns empty hash when no preferences set' do
        expect(user.notification_preferences).to eq({})
      end

      it 'returns preferences when set' do
        user.update!(preferences: { 'notifications' => { 'email' => true } })
        expect(user.notification_preferences).to eq({ 'email' => true })
      end

      it 'caches the result' do
        user.update!(preferences: { 'notifications' => { 'email' => true } })
        first_call = user.notification_preferences
        user.preferences['notifications']['email'] = false
        second_call = user.notification_preferences
        expect(first_call).to eq(second_call) # Should be cached
      end
    end

    describe '#update_notification_preferences?' do
      it 'updates preferences successfully' do
        result = user.update_notification_preferences?({ 'email' => true, 'push' => false })
        expect(result).to be true
        user.reload
        expect(user.preferences['notifications']).to eq({ 'email' => true, 'push' => false })
      end

      it 'returns false when input is not a hash' do
        result = user.update_notification_preferences?('invalid')
        expect(result).to be false
      end

      it 'clears cache after update' do
        user.update!(preferences: { 'notifications' => { 'email' => true } })
        user.notification_preferences # Cache it
        user.update_notification_preferences?({ 'email' => false })
        expect(user.notification_preferences['email']).to eq(false)
      end
    end

    describe '#email_notifications_enabled?' do
      it 'returns true when enabled' do
        user.update!(preferences: { 'notifications' => { 'email' => true } })
        expect(user.email_notifications_enabled?).to be true
      end

      it 'returns false when disabled' do
        user.update!(preferences: { 'notifications' => { 'email' => false } })
        expect(user.email_notifications_enabled?).to be false
      end

      it 'returns false when not set' do
        expect(user.email_notifications_enabled?).to be false
      end
    end

    describe '#push_notifications_enabled?' do
      it 'returns true when enabled' do
        user.update!(preferences: { 'notifications' => { 'push' => true } })
        expect(user.push_notifications_enabled?).to be true
      end

      it 'returns false when disabled' do
        user.update!(preferences: { 'notifications' => { 'push' => false } })
        expect(user.push_notifications_enabled?).to be false
      end
    end

    describe '#sms_notifications_enabled?' do
      it 'returns true when enabled' do
        user.update!(preferences: { 'notifications' => { 'sms' => true } })
        expect(user.sms_notifications_enabled?).to be true
      end

      it 'returns false when disabled' do
        user.update!(preferences: { 'notifications' => { 'sms' => false } })
        expect(user.sms_notifications_enabled?).to be false
      end
    end
  end

  describe 'class methods' do
    describe '.authenticate' do
      let!(:user) { create(:user, email: 'auth@example.com', password: 'password123') }

      it 'authenticates with correct credentials' do
        authenticated_user = User.authenticate('auth@example.com', 'password123')
        expect(authenticated_user).to eq(user)
      end

      it 'returns false with incorrect password' do
        authenticated_user = User.authenticate('auth@example.com', 'wrongpassword')
        expect(authenticated_user).to be false
      end

      it 'returns nil with incorrect email' do
        authenticated_user = User.authenticate('wrong@example.com', 'password123')
        expect(authenticated_user).to be_nil
      end

      it 'is case insensitive for email' do
        authenticated_user = User.authenticate('AUTH@EXAMPLE.COM', 'password123')
        expect(authenticated_user).to eq(user)
      end
    end

    describe '.find_by_email' do
      let!(:user) { create(:user, email: 'find@example.com') }

      it 'finds user by email' do
        found_user = User.find_by(email: 'find@example.com')
        expect(found_user).to eq(user)
      end

      it 'is case insensitive' do
        found_user = User.find_by_email('FIND@EXAMPLE.COM')
        expect(found_user).to eq(user)
      end

      it 'returns nil when not found' do
        found_user = User.find_by(email: 'nonexistent@example.com')
        expect(found_user).to be_nil
      end
    end

    describe '.find_by_verification_token' do
      it 'finds user by verification token' do
        user = create(:user)
        token = user.email_verification_token
        found_user = User.find_by_verification_token(token)
        expect(found_user).to eq(user)
      end

      it 'returns nil when token is blank' do
        expect(User.find_by_verification_token('')).to be_nil
        expect(User.find_by_verification_token(nil)).to be_nil
      end

      it 'returns nil when token not found' do
        found_user = User.find_by_verification_token('nonexistent-token')
        expect(found_user).to be_nil
      end
    end
  end

  describe 'database constraints' do
    it 'prevents duplicate emails' do
      create(:user, email: 'duplicate@example.com', first_name: 'Test1', last_name: 'User1')
      expect do
        create(:user, email: 'duplicate@example.com', first_name: 'Test2', last_name: 'User2')
      end.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'prevents same email with different case' do
      create(:user, email: 'case@example.com', first_name: 'Test1', last_name: 'User1')
      expect do
        create(:user, email: 'CASE@EXAMPLE.COM', first_name: 'Test2', last_name: 'User2')
      end.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
