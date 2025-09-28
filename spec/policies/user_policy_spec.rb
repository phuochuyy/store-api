require 'rails_helper'

RSpec.describe UserPolicy, type: :policy do
  subject { described_class }

  let(:admin_user) { create(:user, role: 'admin') }
  let(:customer_user) { create(:user, role: 'customer') }
  let(:other_customer) { create(:user, role: 'customer') }

  describe 'index?' do
    it 'allows admin users' do
      expect(subject.new(admin_user, customer_user).index?).to be true
    end

    it 'denies customer users' do
      expect(subject.new(customer_user, other_customer).index?).to be false
    end

    it 'denies unauthenticated users' do
      expect(subject.new(nil, customer_user).index?).to be_falsey
    end
  end

  describe 'show?' do
    it 'allows admin users to view any user' do
      expect(subject.new(admin_user, customer_user).show?).to be true
      expect(subject.new(admin_user, other_customer).show?).to be true
    end

    it 'allows users to view themselves' do
      expect(subject.new(customer_user, customer_user).show?).to be true
    end

    it 'denies users from viewing other users' do
      expect(subject.new(customer_user, other_customer).show?).to be false
    end

    it 'denies unauthenticated users' do
      expect(subject.new(nil, customer_user).show?).to be_falsey
    end
  end

  describe 'create?' do
    it 'allows admin users' do
      expect(subject.new(admin_user, customer_user).create?).to be true
    end

    it 'denies customer users' do
      expect(subject.new(customer_user, other_customer).create?).to be false
    end

    it 'denies unauthenticated users' do
      expect(subject.new(nil, customer_user).create?).to be_falsey
    end
  end

  describe 'update?' do
    it 'allows admin users to update any user' do
      expect(subject.new(admin_user, customer_user).update?).to be true
      expect(subject.new(admin_user, other_customer).update?).to be true
    end

    it 'allows users to update themselves' do
      expect(subject.new(customer_user, customer_user).update?).to be true
    end

    it 'denies users from updating other users' do
      expect(subject.new(customer_user, other_customer).update?).to be false
    end

    it 'denies unauthenticated users' do
      expect(subject.new(nil, customer_user).update?).to be_falsey
    end
  end

  describe 'destroy?' do
    it 'allows admin users' do
      expect(subject.new(admin_user, customer_user).destroy?).to be true
    end

    it 'denies customer users' do
      expect(subject.new(customer_user, other_customer).destroy?).to be false
    end

    it 'denies users from deleting themselves' do
      expect(subject.new(customer_user, customer_user).destroy?).to be false
    end

    it 'denies unauthenticated users' do
      expect(subject.new(nil, customer_user).destroy?).to be_falsey
    end
  end

  describe 'owner?' do
    it 'returns true when user is the record owner' do
      policy = subject.new(customer_user, customer_user)
      expect(policy.send(:owner?)).to be true
    end

    it 'returns false when user is not the record owner' do
      policy = subject.new(customer_user, other_customer)
      expect(policy.send(:owner?)).to be false
    end
  end
end
