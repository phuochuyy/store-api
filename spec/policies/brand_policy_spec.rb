require 'rails_helper'

RSpec.describe BrandPolicy, type: :policy do
  subject { described_class }

  let(:admin_user) { create(:user, role: 'admin') }
  let(:customer_user) { create(:user, role: 'customer') }
  let(:brand) { create(:brand) }

  describe 'index?' do
    it 'allows authenticated users' do
      expect(subject.new(admin_user, brand).index?).to be true
      expect(subject.new(customer_user, brand).index?).to be true
    end

    it 'denies unauthenticated users' do
      expect(subject.new(nil, brand).index?).to be false
    end
  end

  describe 'show?' do
    it 'allows authenticated users' do
      expect(subject.new(admin_user, brand).show?).to be true
      expect(subject.new(customer_user, brand).show?).to be true
    end

    it 'denies unauthenticated users' do
      expect(subject.new(nil, brand).show?).to be false
    end
  end

  describe 'create?' do
    it 'allows admin users' do
      expect(subject.new(admin_user, brand).create?).to be true
    end

    it 'denies customer users' do
      expect(subject.new(customer_user, brand).create?).to be false
    end

    it 'denies unauthenticated users' do
      expect(subject.new(nil, brand).create?).to be_falsey
    end
  end

  describe 'update?' do
    it 'allows admin users' do
      expect(subject.new(admin_user, brand).update?).to be true
    end

    it 'denies customer users' do
      expect(subject.new(customer_user, brand).update?).to be false
    end

    it 'denies unauthenticated users' do
      expect(subject.new(nil, brand).update?).to be_falsey
    end
  end

  describe 'destroy?' do
    it 'allows admin users' do
      expect(subject.new(admin_user, brand).destroy?).to be true
    end

    it 'denies customer users' do
      expect(subject.new(customer_user, brand).destroy?).to be false
    end

    it 'denies unauthenticated users' do
      expect(subject.new(nil, brand).destroy?).to be_falsey
    end
  end
end
