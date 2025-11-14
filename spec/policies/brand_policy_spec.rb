require 'rails_helper'

RSpec.describe BrandPolicy, type: :policy do
  let(:user) { create(:user) }
  let(:admin_user) { create(:user, :admin) }
  let(:brand) { create(:brand) }
  let(:policy) { described_class.new(user, brand) }
  let(:admin_policy) { described_class.new(admin_user, brand) }

  describe '#index?' do
    it 'allows authenticated users' do
      expect(policy.index?).to be true
    end

    it 'denies unauthenticated users' do
      nil_policy = described_class.new(nil, brand)
      expect(nil_policy.index?).to be false
    end
  end

  describe '#show?' do
    it 'allows authenticated users' do
      expect(policy.show?).to be true
    end

    it 'denies unauthenticated users' do
      nil_policy = described_class.new(nil, brand)
      expect(nil_policy.show?).to be false
    end
  end

  describe '#create?' do
    it 'allows admin users' do
      expect(admin_policy.create?).to be true
    end

    it 'denies customer users' do
      expect(policy.create?).to be false
    end

    it 'denies unauthenticated users' do
      nil_policy = described_class.new(nil, brand)
      expect(nil_policy.create?).to be false
    end
  end

  describe '#update?' do
    it 'allows admin users' do
      expect(admin_policy.update?).to be true
    end

    it 'denies customer users' do
      expect(policy.update?).to be false
    end

    it 'denies unauthenticated users' do
      nil_policy = described_class.new(nil, brand)
      expect(nil_policy.update?).to be false
    end
  end

  describe '#destroy?' do
    it 'allows admin users' do
      expect(admin_policy.destroy?).to be true
    end

    it 'denies customer users' do
      expect(policy.destroy?).to be false
    end

    it 'denies unauthenticated users' do
      nil_policy = described_class.new(nil, brand)
      expect(nil_policy.destroy?).to be false
    end
  end

  describe 'with new brand record' do
    let(:new_brand) { Brand.new }
    let(:new_policy) { described_class.new(admin_user, new_brand) }

    it 'allows admin to create new brand' do
      expect(new_policy.create?).to be true
    end

    it 'denies customer to create new brand' do
      customer_policy = described_class.new(user, new_brand)
      expect(customer_policy.create?).to be false
    end
  end
end

