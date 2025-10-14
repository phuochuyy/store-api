require 'rails_helper'

RSpec.describe UserPolicy, type: :policy do
  let(:user) { create(:user) }
  let(:admin_user) { create(:user, :admin) }
  let(:other_user) { create(:user) }

  describe '#index?' do
    it 'allows admin users' do
      policy = described_class.new(admin_user, user)
      expect(policy.index?).to be true
    end

    it 'denies customer users' do
      policy = described_class.new(user, other_user)
      expect(policy.index?).to be false
    end
  end

  describe '#show?' do
    it 'allows admin users' do
      policy = described_class.new(admin_user, user)
      expect(policy.show?).to be true
    end

    it 'allows users to view their own profile' do
      policy = described_class.new(user, user)
      expect(policy.show?).to be true
    end

    it 'denies users from viewing other profiles' do
      policy = described_class.new(user, other_user)
      expect(policy.show?).to be false
    end
  end

  describe '#create?' do
    it 'allows admin users' do
      policy = described_class.new(admin_user, user)
      expect(policy.create?).to be true
    end

    it 'denies customer users' do
      policy = described_class.new(user, other_user)
      expect(policy.create?).to be false
    end
  end

  describe '#update?' do
    it 'allows admin users' do
      policy = described_class.new(admin_user, user)
      expect(policy.update?).to be true
    end

    it 'allows users to update their own profile' do
      policy = described_class.new(user, user)
      expect(policy.update?).to be true
    end

    it 'denies users from updating other profiles' do
      policy = described_class.new(user, other_user)
      expect(policy.update?).to be false
    end
  end

  describe '#destroy?' do
    it 'allows admin users' do
      policy = described_class.new(admin_user, user)
      expect(policy.destroy?).to be true
    end

    it 'denies customer users' do
      policy = described_class.new(user, other_user)
      expect(policy.destroy?).to be false
    end

    it 'denies users from deleting their own profile' do
      policy = described_class.new(user, user)
      expect(policy.destroy?).to be false
    end
  end

  describe 'private methods' do
    describe '#owner?' do
      it 'returns true when user is the record owner' do
        policy = described_class.new(user, user)
        expect(policy.send(:owner?)).to be true
      end

      it 'returns false when user is not the record owner' do
        policy = described_class.new(user, other_user)
        expect(policy.send(:owner?)).to be false
      end
    end
  end
end
