require 'rails_helper'

# Api::V1::BaseController is what gives an endpoint JWT authentication, authorize!/admin_only!
# and their 403 handling. A controller that inherits ApplicationController directly has none of
# these, so `before_action :authenticate_user!` raises NoMethodError and every request is a 500.
RSpec.describe 'Api::V1 controller inheritance' do
  # Public by design: health checks must answer without a token.
  let(:exempt) { %w[Api::V1::HealthController] }

  let(:v1_controllers) do
    Rails.autoloaders.main.eager_load_dir(Rails.root.join('app/controllers/api/v1'))
    ApplicationController.descendants.select { |klass| klass.name&.start_with?('Api::V1::') }
  end

  it 'loads the v1 controllers' do
    expect(v1_controllers.size).to be > 20
  end

  it 'makes every v1 controller inherit Api::V1::BaseController' do
    offenders = v1_controllers.reject { |klass| klass <= Api::V1::BaseController }.map(&:name) - exempt

    expect(offenders).to be_empty,
                         "#{offenders.sort.join(', ')} must inherit Api::V1::BaseController, not ApplicationController"
  end
end
