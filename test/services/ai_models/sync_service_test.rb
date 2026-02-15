# frozen_string_literal: true

require "test_helper"

module AiModels
  class SyncServiceTest < ActiveSupport::TestCase
    def setup
      @service = SyncService.new
    end

    test "sync_all creates new models from adapters" do
      stub_openrouter_response([
        {
          "id" => "openai/gpt-4o-test",
          "name" => "GPT-4o Test",
          "context_length" => 128_000,
          "pricing" => { "prompt" => "0.0000025", "completion" => "0.00001" }
        }
      ])
      stub_litellm_response({})

      assert_difference "AiModel.count", 1 do
        @service.sync_all
      end

      model = AiModel.find_by(external_id: "openai/gpt-4o-test")
      assert_not_nil model
      assert_equal "GPT-4o Test", model.name
      assert_equal "OpenAI", model.provider
      assert_equal 128_000, model.context_window
      assert_equal 2.5, model.input_per_1m_tokens.to_f
      assert_equal 10.0, model.output_per_1m_tokens.to_f
      assert_not model.published # New models start unpublished
    end

    test "sync_all updates existing models" do
      existing = create(:ai_model,
                        name: "GPT-4o",
                        external_id: "openai/gpt-4o",
                        provider: "OpenAI",
                        input_per_1m_tokens: 5.0,
                        sync_enabled: true)

      stub_openrouter_response([
        {
          "id" => "openai/gpt-4o",
          "name" => "GPT-4o",
          "pricing" => { "prompt" => "0.0000025", "completion" => "0.00001" }
        }
      ])
      stub_litellm_response({})

      assert_no_difference "AiModel.count" do
        @service.sync_all
      end

      existing.reload
      assert_equal 2.5, existing.input_per_1m_tokens.to_f
      assert_equal 1, existing.sync_changes.count
    end

    test "sync_all creates change records for updates" do
      existing = create(:ai_model,
                        external_id: "openai/gpt-4o",
                        provider: "OpenAI",
                        input_per_1m_tokens: 5.0)

      stub_openrouter_response([
        {
          "id" => "openai/gpt-4o",
          "name" => "GPT-4o",
          "pricing" => { "prompt" => "0.0000025", "completion" => "0.00001" }
        }
      ])
      stub_litellm_response({})

      assert_difference "AiModelChange.count", 1 do
        @service.sync_all
      end

      change = existing.sync_changes.last
      assert_equal "pricing_change", change.change_type
      assert_equal "openrouter", change.source
      # Compare as floats since DB may return BigDecimal
      assert_equal 5.0, change.old_values["input_per_1m_tokens"].to_f
    end

    test "sync_all respects source priority" do
      existing = create(:ai_model,
                        external_id: "openai/gpt-4o",
                        provider: "OpenAI",
                        input_per_1m_tokens: 5.0,
                        sync_source: "openai_api") # Higher priority

      stub_openrouter_response([
        {
          "id" => "openai/gpt-4o",
          "name" => "GPT-4o",
          "pricing" => { "prompt" => "0.0000025", "completion" => "0.00001" }
        }
      ])
      stub_litellm_response({})

      @service.sync_all

      existing.reload
      assert_equal 5.0, existing.input_per_1m_tokens.to_f # Not updated
    end

    test "quick_sync only updates pricing fields" do
      existing = create(:ai_model,
                        external_id: "openai/gpt-4o",
                        provider: "OpenAI",
                        name: "Original Name",
                        input_per_1m_tokens: 5.0)

      stub_openrouter_response([
        {
          "id" => "openai/gpt-4o",
          "name" => "New Name",
          "pricing" => { "prompt" => "0.0000025", "completion" => "0.00001" }
        }
      ])

      @service.quick_sync

      existing.reload
      assert_equal "Original Name", existing.name # Name not changed
      assert_equal 2.5, existing.input_per_1m_tokens.to_f # Pricing updated
    end

    test "sync_provider only syncs specified provider" do
      stub_openrouter_response([
        {
          "id" => "openai/gpt-4o",
          "name" => "GPT-4o",
          "pricing" => { "prompt" => "0.0000025", "completion" => "0.00001" }
        },
        {
          "id" => "anthropic/claude-3-opus",
          "name" => "Claude 3 Opus",
          "pricing" => { "prompt" => "0.000015", "completion" => "0.000075" }
        }
      ])
      stub_litellm_response({})

      @service.sync_provider("OpenAI")

      assert AiModel.exists?(external_id: "openai/gpt-4o")
      assert_not AiModel.exists?(external_id: "anthropic/claude-3-opus")
    end

    test "sync returns stats" do
      stub_openrouter_response([
        {
          "id" => "openai/gpt-4o-new",
          "name" => "GPT-4o New",
          "pricing" => { "prompt" => "0.0000025", "completion" => "0.00001" }
        }
      ])
      stub_litellm_response({})

      stats = @service.sync_all

      assert_equal 1, stats[:created]
      assert_equal 0, stats[:updated]
    end

    private

    def stub_openrouter_response(models)
      # Mock at adapter level for reliability
      normalized_models = models.map do |m|
        provider_slug = m["id"].split("/").first
        {
          external_id: m["id"],
          name: m["name"] || m["id"].split("/").last,
          provider: provider_mapping[provider_slug] || provider_slug.titleize,
          api_model_id: m["id"],
          context_window: m["context_length"],
          max_output_tokens: m.dig("top_provider", "max_completion_tokens"),
          input_per_1m_tokens: m.dig("pricing", "prompt") ? m.dig("pricing", "prompt").to_f * 1_000_000 : nil,
          output_per_1m_tokens: m.dig("pricing", "completion") ? m.dig("pricing", "completion").to_f * 1_000_000 : nil,
          supports_vision: false,
          supports_function_calling: false,
          supports_json_mode: false,
          supports_streaming: true,
          status: "active"
        }.compact
      end.select { |m| AiModel::PROVIDERS.include?(m[:provider]) }

      Adapters::OpenrouterAdapter.any_instance.stubs(:fetch_models).returns(normalized_models)
    end

    def stub_litellm_response(_models)
      # Return empty array to avoid interference
      Adapters::LitellmAdapter.any_instance.stubs(:fetch_models).returns([])
    end

    def provider_mapping
      {
        "openai" => "OpenAI",
        "anthropic" => "Anthropic",
        "google" => "Google",
        "meta-llama" => "Meta",
        "mistralai" => "Mistral",
        "x-ai" => "xAI",
        "deepseek" => "DeepSeek"
      }
    end
  end
end
