require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe UserAddress, type: :model do
  let(:user) { create(:user) }
  let(:address) { create(:user_address, user: user) }

  describe 'associations' do
    it { should belong_to(:user) }
  end

  describe 'validations' do
    it { should validate_presence_of(:full_name) }
    it { should validate_presence_of(:address_line1) }
    it { should validate_presence_of(:city) }
    it { should validate_presence_of(:postal_code) }
    it { should validate_presence_of(:country) }
    it { should validate_inclusion_of(:address_type).in_array(%w[shipping billing]) }
  end

  describe '#set_as_default!' do
    it 'sets address as default for its type' do
      address.set_as_default!
      expect(address.reload.is_default).to be true
    end

    it 'unsets other default addresses of same type' do
      address1 = create(:user_address, user: user, address_type: 'shipping', is_default: true)
      address2 = create(:user_address, user: user, address_type: 'shipping', is_default: false)
      address2.set_as_default!
      expect(address1.reload.is_default).to be false
      expect(address2.reload.is_default).to be true
    end

    it 'does not affect addresses of different type' do
      shipping = create(:user_address, user: user, address_type: 'shipping', is_default: true)
      billing = create(:user_address, user: user, address_type: 'billing', is_default: false)
      billing.set_as_default!
      expect(shipping.reload.is_default).to be true
      expect(billing.reload.is_default).to be true
    end
  end
end
# rubocop:enable Metrics/BlockLength
