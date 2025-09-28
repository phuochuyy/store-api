require 'rails_helper'

RSpec.describe ProductPolicy, type: :policy do
  subject { described_class }

  let(:admin_user) { create(:user, role: 'admin') }
  let(:customer_user) { create(:user, role: 'customer') }
  let(:brand) { create(:brand) }
  let(:category) { create(:category) }
  let(:product) { create(:product, brand: brand, category: category) }

  describe 'index?' do
    it 'allows authenticated users' do
      expect(subject.new(admin_user, product).index?).to be true
      expect(subject.new(customer_user, product).index?).to be true
    end

    it 'denies unauthenticated users' do
      expect(subject.new(nil, product).index?).to be false
    end
  end

  describe 'show?' do
    it 'allows authenticated users' do
      expect(subject.new(admin_user, product).show?).to be true
      expect(subject.new(customer_user, product).show?).to be true
    end

    it 'denies unauthenticated users' do
      expect(subject.new(nil, product).show?).to be false
    end
  end

  describe 'create?' do
    it 'allows admin users' do
      expect(subject.new(admin_user, product).create?).to be true
    end

    it 'denies customer users' do
      expect(subject.new(customer_user, product).create?).to be false
    end

    it 'denies unauthenticated users' do
      expect(subject.new(nil, product).create?).to be_falsey
    end
  end

  describe 'update?' do
    it 'allows admin users' do
      expect(subject.new(admin_user, product).update?).to be true
    end

    it 'denies customer users' do
      expect(subject.new(customer_user, product).update?).to be false
    end

    it 'denies unauthenticated users' do
      expect(subject.new(nil, product).update?).to be_falsey
    end
  end

  describe 'destroy?' do
    it 'allows admin users' do
      expect(subject.new(admin_user, product).destroy?).to be true
    end

    it 'denies customer users' do
      expect(subject.new(customer_user, product).destroy?).to be false
    end

    it 'denies unauthenticated users' do
      expect(subject.new(nil, product).destroy?).to be_falsey
    end
  end

  describe 'upload_image?' do
    it 'allows admin users' do
      expect(subject.new(admin_user, product).upload_image?).to be true
    end

    it 'denies customer users' do
      expect(subject.new(customer_user, product).upload_image?).to be false
    end

    it 'denies unauthenticated users' do
      expect(subject.new(nil, product).upload_image?).to be_falsey
    end
  end

  describe 'remove_image?' do
    it 'allows admin users' do
      expect(subject.new(admin_user, product).remove_image?).to be true
    end

    it 'denies customer users' do
      expect(subject.new(customer_user, product).remove_image?).to be false
    end

    it 'denies unauthenticated users' do
      expect(subject.new(nil, product).remove_image?).to be_falsey
    end
  end
end
