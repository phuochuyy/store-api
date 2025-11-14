require 'rails_helper'

RSpec.describe ProductReview, type: :model do
  let(:user) { create(:user) }
  let(:product) { create(:product) }
  let(:review) { create(:product_review, user: user, product: product) }

  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:product) }
  end

  describe 'validations' do
    it { should validate_presence_of(:rating) }
    it { should validate_inclusion_of(:rating).in_array([1, 2, 3, 4, 5]) }
    it { should validate_uniqueness_of(:user_id).scoped_to(:product_id) }
  end

  describe 'scopes' do
    let!(:approved_review) { create(:product_review, status: 'approved') }
    let!(:pending_review) { create(:product_review, :pending) }
    let!(:verified_review) { create(:product_review, :verified) }

    describe '.approved' do
      it 'returns only approved reviews' do
        expect(ProductReview.approved).to include(approved_review)
        expect(ProductReview.approved).not_to include(pending_review)
      end
    end

    describe '.verified_purchases' do
      it 'returns only verified purchase reviews' do
        expect(ProductReview.verified_purchases).to include(verified_review)
        expect(ProductReview.verified_purchases).not_to include(approved_review)
      end
    end

    describe '.most_helpful' do
      it 'orders by helpful_count desc' do
        review1 = create(:product_review, helpful_count: 10)
        review2 = create(:product_review, helpful_count: 5)
        expect(ProductReview.most_helpful.first).to eq(review1)
      end
    end
  end
end

