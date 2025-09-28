require 'rails_helper'

RSpec.describe PhonePolicy, type: :policy do
  subject { described_class }

  let(:admin_user) { create(:user, role: 'admin') }
  let(:customer_user) { create(:user, role: 'customer') }
  let(:brand) { create(:brand) }
  let(:category) { create(:category) }
  let(:phone) { create(:phone, brand: brand, category: category) }

  describe 'index?' do
    it 'allows authenticated users' do
      expect(subject.new(admin_user, phone).index?).to be true
      expect(subject.new(customer_user, phone).index?).to be true
    end

    it 'denies unauthenticated users' do
      expect(subject.new(nil, phone).index?).to be false
    end
  end

  describe 'show?' do
    it 'allows authenticated users' do
      expect(subject.new(admin_user, phone).show?).to be true
      expect(subject.new(customer_user, phone).show?).to be true
    end

    it 'denies unauthenticated users' do
      expect(subject.new(nil, phone).show?).to be false
    end
  end

  describe 'create?' do
    it 'allows admin users' do
      expect(subject.new(admin_user, phone).create?).to be true
    end

    it 'denies customer users' do
      expect(subject.new(customer_user, phone).create?).to be false
    end

    it 'denies unauthenticated users' do
      expect(subject.new(nil, phone).create?).to be_falsey
    end
  end

  describe 'update?' do
    it 'allows admin users' do
      expect(subject.new(admin_user, phone).update?).to be true
    end

    it 'denies customer users' do
      expect(subject.new(customer_user, phone).update?).to be false
    end

    it 'denies unauthenticated users' do
      expect(subject.new(nil, phone).update?).to be_falsey
    end
  end

  describe 'destroy?' do
    it 'allows admin users' do
      expect(subject.new(admin_user, phone).destroy?).to be true
    end

    it 'denies customer users' do
      expect(subject.new(customer_user, phone).destroy?).to be false
    end

    it 'denies unauthenticated users' do
      expect(subject.new(nil, phone).destroy?).to be_falsey
    end
  end

  describe 'upload_image?' do
    it 'allows admin users' do
      expect(subject.new(admin_user, phone).upload_image?).to be true
    end

    it 'denies customer users' do
      expect(subject.new(customer_user, phone).upload_image?).to be false
    end

    it 'denies unauthenticated users' do
      expect(subject.new(nil, phone).upload_image?).to be_falsey
    end
  end

  describe 'remove_image?' do
    it 'allows admin users' do
      expect(subject.new(admin_user, phone).remove_image?).to be true
    end

    it 'denies customer users' do
      expect(subject.new(customer_user, phone).remove_image?).to be false
    end

    it 'denies unauthenticated users' do
      expect(subject.new(nil, phone).remove_image?).to be_falsey
    end
  end
end
