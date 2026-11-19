module Search
  # Which engine serves product search. SQL (Search::Like) is the default; set
  # SEARCH_BACKEND=elasticsearch to use the Elasticsearch index (Searchkick). If the
  # cluster is unreachable, Products::ProductService falls back to SQL.
  module Backend
    module_function

    def elasticsearch?
      ENV.fetch('SEARCH_BACKEND', 'sql') == 'elasticsearch'
    end
  end
end
