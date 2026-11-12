# Product search on Elasticsearch through Searchkick (enabled with SEARCH_BACKEND=elasticsearch).
# The cluster URL comes from ELASTICSEARCH_URL (default http://localhost:9200).
#
# Keep requests short: when the cluster is slow or down, product search falls back to SQL
# instead of holding the request open.
Searchkick.timeout = 2
Searchkick.client_options = { retry_on_failure: 1, request_timeout: 2 }
