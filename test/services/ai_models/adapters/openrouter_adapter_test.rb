# frozen_string_literal: true

require "test_helper"

module AiModels
  module Adapters
    class OpenrouterAdapterTest < ActiveSupport::TestCase
      def setup
        @adapter = OpenrouterAdapter.new
      end

      test "fetches and normalizes models from OpenRouter API" do
        stub_openrouter_api([
          {
            "id" => "openai/gpt-4o",
            "name" => "GPT-4o",
            "context_length" => 128_000,
            "pricing" => {
              "prompt" => "0.0000025",
              "completion" => "0.00001"
            },
            "architecture" => {
              "modality" => "text+image",
              "instruct_type" => "json"
            },
            "top_provider" => {
              "max_completion_tokens" => 16_384
            }
          }
        ])

        models = @adapter.fetch_models

        assert_equal 1, models.length

        model = models.first
        assert_equal "openai/gpt-4o", model[:external_id]
        assert_equal "GPT-4o", model[:name]
        assert_equal "OpenAI", model[:provider]
        assert_equal 128_000, model[:context_window]
        assert_equal 16_384, model[:max_output_tokens]
        assert_equal 2.5, model[:input_per_1m_tokens]
        assert_equal 10.0, model[:output_per_1m_tokens]
        assert model[:supports_vision]
        assert model[:supports_json_mode]
      end

      test "normalizes provider names correctly" do
        stub_openrouter_api([
          { "id" => "openai/gpt-4", "name" => "GPT-4" },
          { "id" => "anthropic/claude-3", "name" => "Claude 3" },
          { "id" => "google/gemini-pro", "name" => "Gemini Pro" },
          { "id" => "meta-llama/llama-3", "name" => "Llama 3" },
          { "id" => "mistralai/mistral-large", "name" => "Mistral Large" },
          { "id" => "x-ai/grok-2", "name" => "Grok 2" },
          { "id" => "deepseek/deepseek-chat", "name" => "DeepSeek Chat" }
        ])

        models = @adapter.fetch_models
        providers = models.map { |m| m[:provider] }

        assert_includes providers, "OpenAI"
        assert_includes providers, "Anthropic"
        assert_includes providers, "Google"
        assert_includes providers, "Meta"
        assert_includes providers, "Mistral"
        assert_includes providers, "xAI"
        assert_includes providers, "DeepSeek"
      end

      test "skips models from unknown providers" do
        stub_openrouter_api([
          { "id" => "openai/gpt-4", "name" => "GPT-4" },
          { "id" => "unknownprovider/some-model", "name" => "Some Model" }
        ])

        models = @adapter.fetch_models

        assert_equal 1, models.length
        assert_equal "OpenAI", models.first[:provider]
      end

      test "handles empty response" do
        stub_openrouter_api([])

        models = @adapter.fetch_models

        assert_equal 0, models.length
      end

      test "handles API errors gracefully" do
        stub_request(:get, "https://openrouter.ai/api/v1/models")
          .to_return(status: 500, body: "Internal Server Error")

        models = @adapter.fetch_models

        assert_equal 0, models.length
      end

      test "returns correct source identifier" do
        assert_equal "openrouter", @adapter.source
      end

      private

      def stub_openrouter_api(models)
        stub_request(:get, "https://openrouter.ai/api/v1/models")
          .to_return(
            status: 200,
            body: { "data" => models }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end
    end
  end
end
