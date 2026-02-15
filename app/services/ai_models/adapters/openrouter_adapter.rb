# frozen_string_literal: true

module AiModels
  module Adapters
    class OpenrouterAdapter < BaseAdapter
      OPENROUTER_API_URL = "https://openrouter.ai/api/v1/models"

      def source
        "openrouter"
      end

      def fetch_models
        raw_data = fetch_json(OPENROUTER_API_URL)
        models = raw_data["data"] || []

        logger.info("[OpenRouter] Fetched #{models.count} models")

        models.map { |model| normalize(model) }.compact
      rescue FetchError, ParseError => e
        logger.error("[OpenRouter] Error: #{e.message}")
        []
      end

      def normalize(raw)
        return nil if raw["id"].blank?

        # Extract provider from model ID (e.g., "openai/gpt-4o" -> "openai")
        provider_slug = raw["id"].split("/").first
        provider = normalize_provider(provider_slug)

        # Skip providers we don't track
        return nil unless AiModel::PROVIDERS.include?(provider)

        pricing = raw["pricing"] || {}

        {
          external_id: raw["id"],
          name: raw["name"] || raw["id"].split("/").last,
          provider: provider,
          api_model_id: raw["id"],
          context_window: raw["context_length"],
          max_output_tokens: raw["top_provider"]&.dig("max_completion_tokens"),
          input_per_1m_tokens: to_per_million(pricing["prompt"]),
          output_per_1m_tokens: to_per_million(pricing["completion"]),
          supports_vision: raw["architecture"]&.dig("modality")&.include?("image") || false,
          supports_function_calling: raw["architecture"]&.dig("instruct_type") == "json" ||
                                      raw["description"]&.include?("function") || false,
          supports_json_mode: raw["architecture"]&.dig("instruct_type") == "json" || false,
          supports_streaming: true, # Most models support streaming
          status: "active"
        }
      end
    end
  end
end
