require "simplecov"
SimpleCov.start "rails" do
  add_filter "/test/"
  minimum_coverage 60
end

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "factory_bot_rails"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add FactoryBot methods
    include FactoryBot::Syntax::Methods

    # Add Shoulda::Matchers DSL
    extend Shoulda::Matchers::ActiveRecord
    extend Shoulda::Matchers::ActiveModel
  end
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :minitest
    with.library :rails
  end
end
