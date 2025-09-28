require 'rails_helper'

RSpec.describe CategoryPolicy, type: :policy do
  subject { described_class }

  let(:admin_user) { create(:user, role: 'admin') }
  let(:customer_user) { create(:user, role: 'customer') }
  let(:category) { create(:category) }

  describe 'index?' do
    it 'allows authenticated users' do
      expect(subject.new(admin_user, category).index?).to be true
      expect(subject.new(customer_user, category).index?).to be true
    end

    it 'denies unauthenticated users' do
      expect(subject.new(nil, category).index?).to be false
    end
  end

  describe 'show?' do
    it 'allows authenticated users' do
      expect(subject.new(admin_user, category).show?).to be true
      expect(subject.new(customer_user, category).show?).to be true
    end

    it 'denies unauthenticated users' do
      expect(subject.new(nil, category).show?).to be false
    end
  end

  describe 'create?' do
    it 'allows admin users' do
      expect(subject.new(admin_user, category).create?).to be true
    end

    it 'denies customer users' do
      expect(subject.new(customer_user, category).create?).to be false
    end

    it 'denies unauthenticated users' do
      expect(subject.new(nil, category).create?).to be_falsey
    end
  end

  describe 'update?' do
    it 'allows admin users' do
      expect(subject.new(admin_user, category).update?).to be true
    end

    it 'denies customer users' do
      expect(subject.new(customer_user, category).update?).to be false
    end

    it 'denies unauthenticated users' do
      expect(subject.new(nil, category).update?).to be_falsey
    end
  end

  describe 'destroy?' do
    it 'allows admin users' do
      expect(subject.new(admin_user, category).destroy?).to be true
    end

    it 'denies customer users' do
      expect(subject.new(customer_user, category).destroy?).to be false
    end

    it 'denies unauthenticated users' do
      expect(subject.new(nil, category).destroy?).to be_falsey
    end
  end
end
