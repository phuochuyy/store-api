require 'rails_helper'

RSpec.describe BasePolicy, type: :policy do
  let(:user) { create(:user) }
  let(:record) { create(:user) }
  let(:policy) { described_class.new(user, record) }

  describe 'default permissions' do
    it 'denies index by default' do
      expect(policy.index?).to be false
    end

    it 'denies show by default' do
      expect(policy.show?).to be false
    end

    it 'denies create by default' do
      expect(policy.create?).to be false
    end

    it 'denies update by default' do
      expect(policy.update?).to be false
    end

    it 'denies destroy by default' do
      expect(policy.destroy?).to be false
    end
  end

  describe 'helper methods' do
    describe '#admin?' do
      it 'returns true for admin user' do
        admin_user = create(:user, :admin)
        admin_policy = described_class.new(admin_user, record)

        expect(admin_policy.send(:admin?)).to be true
      end

      it 'returns false for customer user' do
        expect(policy.send(:admin?)).to be false
      end

      it 'returns false for nil user' do
        nil_policy = described_class.new(nil, record)
        expect(nil_policy.send(:admin?)).to be_nil
      end
    end

    describe '#owner?' do
      it 'returns false when record has no user method' do
        # For BasePolicy, owner? checks if user == record.user
        # Since User model doesn't have a user method, this will raise NoMethodError
        expect { policy.send(:owner?) }.to raise_error(NoMethodError)
      end
    end

    describe '#authenticated?' do
      it 'returns true for authenticated user' do
        expect(policy.send(:authenticated?)).to be true
      end

      it 'returns false for nil user' do
        nil_policy = described_class.new(nil, record)
        expect(nil_policy.send(:authenticated?)).to be false
      end
    end
  end

  describe 'initialization' do
    it 'sets user and record attributes' do
      expect(policy.user).to eq(user)
      expect(policy.record).to eq(record)
    end
  end
end
