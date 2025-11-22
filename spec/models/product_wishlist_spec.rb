require 'rails_helper'

RSpec.describe ProductWishlist, type: :model do
  let(:user) { create(:user) }
  let(:product) { create(:product) }
  let(:wishlist) { create(:product_wishlist, user: user, product: product) }

  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:product) }
  end

  describe 'validations' do
    it { should validate_uniqueness_of(:user_id).scoped_to(:product_id) }
  end
end
