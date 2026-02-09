# frozen_string_literal: true

# OpenAI configuration
# API key can be set via credentials or environment variable
OpenAI.configure do |config|
  config.access_token = Rails.application.credentials.dig(:openai, :api_key) || ENV["OPENAI_API_KEY"]
  config.organization_id = Rails.application.credentials.dig(:openai, :organization_id) || ENV["OPENAI_ORGANIZATION_ID"]

  # Request timeout settings
  config.request_timeout = 120

  # Log requests in development
  config.log_errors = Rails.env.development?
end
