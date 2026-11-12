module Search
  # Case-insensitive "contains" condition that behaves the same on PostgreSQL (ILIKE) and
  # MySQL (LIKE under the default case-insensitive collation). The term is escaped, so a
  # user typing % or _ matches those characters instead of using them as wildcards.
  #
  #   Product.where(Search::Like.contains(Product.arel_table[:name], params[:q]))
  #   Product.left_joins(:brand).where(Search::Like.contains([Product.arel_table[:name], Brand.arel_table[:name]], q))
  module Like
    module_function

    def contains(columns, term)
      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(term.to_s)}%"
      # Array.wrap, not Array(): an Arel attribute is a Struct, which Array() would split.
      Array.wrap(columns).map { |column| column.matches(pattern) }.reduce(:or)
    end
  end
end
