require 'rails_helper'

# db/seeds.rb wipes every table and creates demo accounts with known passwords
# (admin@example.com / password). `db:prepare` seeds a freshly created database, so on a
# production deployment it must not run unless asked for explicitly.
RSpec.describe 'db/seeds.rb' do
  def load_seeds = load(Rails.root.join('db/seeds.rb'))

  around do |example|
    previous = ENV.delete('SEED_DEMO_DATA')
    example.run
  ensure
    ENV['SEED_DEMO_DATA'] = previous
  end

  context 'in production' do
    before { allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new('production')) }

    it 'neither wipes existing data nor creates the demo accounts' do
      customer = create(:user, email: 'real.customer@example.com')

      expect { load_seeds }.to output(/Skipping demo seeds/).to_stderr

      expect(User.exists?(customer.id)).to be true
      expect(User.exists?(email: 'admin@example.com')).to be false
    end
  end
end
