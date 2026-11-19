# Brand and category names are copied into each product's search document, so renaming a
# brand or category must reindex its products; otherwise search keeps matching the old name.
module ReindexesProductsOnRename
  extend ActiveSupport::Concern

  included do
    after_update_commit :reindex_products, if: -> { saved_change_to_name? && Search::Backend.elasticsearch? }
  end

  private

  def reindex_products
    products.reindex
  end
end
