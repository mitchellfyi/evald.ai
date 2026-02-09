# frozen_string_literal: true

# Rack::Timeout configuration
# Aborts requests that take too long, preventing thread pool exhaustion
#
# Configuration via environment variables (preferred) or direct assignment

# Set timeouts via environment variables for flexibility
ENV["RACK_TIMEOUT_SERVICE_TIMEOUT"] ||= "15"   # max time for app to process request
ENV["RACK_TIMEOUT_WAIT_TIMEOUT"] ||= "30"      # max time request can wait in queue
ENV["RACK_TIMEOUT_WAIT_OVERTIME"] ||= "60"     # additional wait time before first byte
ENV["RACK_TIMEOUT_SERVICE_PAST_WAIT"] ||= "false"

# Suppress verbose logging
Rack::Timeout::Logger.level = Logger::WARN

# Disable in test environment to avoid flaky tests
if Rails.env.test?
  ENV["RACK_TIMEOUT_SERVICE_TIMEOUT"] = "0"
  ENV["RACK_TIMEOUT_WAIT_TIMEOUT"] = "0"
end
