# frozen_string_literal: true

module AiModels
  module Adapters
    class LitellmAdapter < BaseAdapter
      LITELLM_JSON_URL = "https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json"

      def source
        "litellm"
      end

      def fetch_models
        raw_data = fetch_json(LITELLM_JSON_URL)

        # LiteLLM format: { "model_id": { "max_tokens": ..., "input_cost_per_token": ... } }
        models = raw_data.map do |model_id, data|
          next if data.is_a?(String) # Skip metadata entries

          normalize(model_id, data)
        end.compact

        logger.info("[LiteLLM] Fetched #{models.count} models")
        models
      rescue FetchError, ParseError => e
        logger.error("[LiteLLM] Error: #{e.message}")
        []
      end

      def normalize(model_id, raw)
        return nil if model_id.blank? || raw.nil?

        # Extract provider from model ID
        provider = extract_provider(model_id, raw)
        return nil unless provider && AiModel::PROVIDERS.include?(provider)

        # Clean up model name
        name = extract_name(model_id)

        {
          external_id: model_id,
          name: name,
          provider: provider,
          api_model_id: model_id,
          context_window: raw["max_tokens"] || raw["max_input_tokens"],
          max_output_tokens: raw["max_output_tokens"],
          input_per_1m_tokens: to_per_million(raw["input_cost_per_token"]),
          output_per_1m_tokens: to_per_million(raw["output_cost_per_token"]),
          cached_input_per_1m_tokens: to_per_million(raw["cache_read_input_token_cost"]),
          supports_vision: raw["supports_vision"] || false,
          supports_function_calling: raw["supports_function_calling"] || raw["supports_tool_choice"] || false,
          supports_streaming: true,
          status: "active"
        }
      end

      private

      def extract_provider(model_id, raw)
        # Check litellm_provider field first
        if raw["litellm_provider"]
          return normalize_provider(raw["litellm_provider"].split("/").first)
        end

        # Fallback to parsing model_id
        provider_mappings = {
          /^gpt-|^o1|^o3|^chatgpt|^text-embedding|^dall-e|^whisper|^tts/i => "OpenAI",
          /^claude-/i => "Anthropic",
          /^gemini-|^palm/i => "Google",
          /^llama|^meta-llama/i => "Meta",
          /^mistral|^mixtral|^codestral/i => "Mistral",
          /^command|^cohere/i => "Cohere",
          /^grok/i => "xAI",
          /^deepseek/i => "DeepSeek",
          /^qwen/i => "Alibaba",
          /^amazon\./i => "Amazon"
        }

        provider_mappings.each do |pattern, provider|
          return provider if model_id.match?(pattern)
        end

        nil
      end

      def extract_name(model_id)
        # Remove provider prefix if present
        name = model_id.gsub(%r{^[a-z-]+/}, "")
        # Capitalize and format
        name.split("-").map(&:capitalize).join(" ").gsub(/(\d)([a-z])/i, '\1 \2')
      end
    end
  end
end
