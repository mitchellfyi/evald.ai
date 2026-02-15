# frozen_string_literal: true

module AiModels
  module Adapters
    class BaseAdapter
      class FetchError < StandardError; end
      class ParseError < StandardError; end

      attr_reader :logger

      def initialize(logger: Rails.logger)
        @logger = logger
      end

      # Returns an array of model data hashes
      def fetch_models
        raise NotImplementedError, "#{self.class} must implement #fetch_models"
      end

      # Returns the source identifier for this adapter
      def source
        raise NotImplementedError, "#{self.class} must implement #source"
      end

      # Normalize model data to match AiModel schema
      def normalize(raw_data)
        raise NotImplementedError, "#{self.class} must implement #normalize"
      end

      protected

      def http_client
        @http_client ||= Faraday.new do |conn|
          conn.options.timeout = 30
          conn.options.open_timeout = 10
          conn.request :json
          conn.response :json, content_type: /\bjson$/
          conn.response :raise_error
          conn.adapter Faraday.default_adapter
        end
      end

      def fetch_json(url, headers: {})
        response = http_client.get(url, nil, headers)
        response.body
      rescue Faraday::Error => e
        logger.error("[#{self.class.name}] Failed to fetch #{url}: #{e.message}")
        raise FetchError, "Failed to fetch data: #{e.message}"
      end

      # Map provider names to our canonical format
      def normalize_provider(provider_name)
        mapping = {
          "openai" => "OpenAI",
          "anthropic" => "Anthropic",
          "google" => "Google",
          "meta-llama" => "Meta",
          "meta" => "Meta",
          "mistralai" => "Mistral",
          "mistral" => "Mistral",
          "cohere" => "Cohere",
          "x-ai" => "xAI",
          "xai" => "xAI",
          "deepseek" => "DeepSeek",
          "alibaba" => "Alibaba",
          "qwen" => "Alibaba",
          "amazon" => "Amazon"
        }
        mapping[provider_name.to_s.downcase] || provider_name.to_s.titleize
      end

      # Convert tokens to pricing per 1M tokens
      def to_per_million(price_per_token)
        return nil unless price_per_token

        (price_per_token.to_f * 1_000_000).round(4)
      end
    end
  end
end
