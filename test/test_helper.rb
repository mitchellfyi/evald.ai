require "simplecov"
SimpleCov.start "rails" do
  add_filter "/test/"
  minimum_coverage 60
end

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "factory_bot_rails"
require "webmock/minitest"
require "mocha/minitest"
require "ostruct"

# Disable all external HTTP requests by default
# Tests that need external calls must explicitly stub them
WebMock.disable_net_connect!(allow_localhost: true)

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    # Set to 1 for accurate SimpleCov reporting; CI may override
    parallelize(workers: ENV.fetch("PARALLEL_WORKERS", 1).to_i)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add FactoryBot methods
    include FactoryBot::Syntax::Methods
  end
end
