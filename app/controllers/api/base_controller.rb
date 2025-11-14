module Api
  class BaseController < ApplicationController
    include Api::Authentication
    include Api::Authorization
    include Common::Pagination
    include Common::Filtering
  end
end
