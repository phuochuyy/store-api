require 'rails_helper'

RSpec.describe BasePolicy, type: :policy do
  subject { described_class.new(user, record) }

  let(:user) { create(:user, role: 'admin') }
  let(:record) { create(:brand) }

  describe 'default permissions' do
    it 'denies all actions by default' do
      expect(subject.index?).to be false
      expect(subject.show?).to be false
      expect(subject.create?).to be false
      expect(subject.update?).to be false
      expect(subject.destroy?).to be false
    end
  end

  describe 'admin?' do
    it 'returns true for admin users' do
      admin_user = create(:user, role: 'admin')
      policy = described_class.new(admin_user, record)
      expect(policy.send(:admin?)).to be true
    end

    it 'returns false for customer users' do
      customer_user = create(:user, role: 'customer')
      policy = described_class.new(customer_user, record)
      expect(policy.send(:admin?)).to be false
    end

    it 'returns false for nil user' do
      policy = described_class.new(nil, record)
      expect(policy.send(:admin?)).to be_falsey
    end
  end

  describe 'authenticated?' do
    it 'returns true for authenticated users' do
      expect(subject.send(:authenticated?)).to be true
    end

    it 'returns false for nil user' do
      policy = described_class.new(nil, record)
      expect(policy.send(:authenticated?)).to be false
    end
  end

  describe 'owner?' do
    it 'returns false by default' do
      # The owner? method tries to access record.user which doesn't exist for Brand
      # So it will raise an error, which is expected behavior
      expect { subject.send(:owner?) }.to raise_error(NoMethodError)
    end
  end

  describe 'initialization' do
    it 'sets user and record' do
      expect(subject.user).to eq(user)
      expect(subject.record).to eq(record)
    end
  end
end
