# frozen_string_literal: true

require "test_helper"

class AiModelTest < ActiveSupport::TestCase
  test "factory creates valid model" do
    model = build(:ai_model)
    assert model.valid?
  end

  test "requires name" do
    model = build(:ai_model, name: nil)
    assert_not model.valid?
    assert_includes model.errors[:name], "can't be blank"
  end

  test "requires provider" do
    model = build(:ai_model, provider: nil)
    assert_not model.valid?
    assert_includes model.errors[:provider], "can't be blank"
  end

  test "requires slug" do
    model = build(:ai_model, slug: nil, name: nil)
    assert_not model.valid?
  end

  test "slug must be unique" do
    create(:ai_model, slug: "test-model")
    model = build(:ai_model, slug: "test-model")
    assert_not model.valid?
    assert_includes model.errors[:slug], "has already been taken"
  end

  test "slug format validation" do
    model = build(:ai_model, slug: "Invalid Slug!")
    assert_not model.valid?
  end

  test "generates slug from name on create" do
    model = build(:ai_model, name: "Claude 3.5 Sonnet", slug: nil)
    model.valid?
    assert_equal "claude-3-5-sonnet", model.slug
  end

  test "to_param returns slug" do
    model = build(:ai_model, slug: "gpt-4o")
    assert_equal "gpt-4o", model.to_param
  end

  test "pricing_summary with both prices" do
    model = build(:ai_model, input_per_1m_tokens: 3.0, output_per_1m_tokens: 15.0)
    assert_equal "$3.0/1M input, $15.0/1M output", model.pricing_summary
  end

  test "pricing_summary with no prices" do
    model = build(:ai_model, input_per_1m_tokens: nil, output_per_1m_tokens: nil)
    assert_equal "", model.pricing_summary
  end

  test "capabilities_list returns enabled capabilities" do
    model = build(:ai_model, supports_vision: true, supports_function_calling: true,
                             supports_json_mode: false, supports_streaming: true,
                             supports_fine_tuning: false, supports_embedding: false)
    assert_equal ["Vision", "Function Calling", "Streaming"], model.capabilities_list
  end

  test "formatted_context_window for millions" do
    model = build(:ai_model, context_window: 1_000_000)
    assert_equal "1.0M", model.formatted_context_window
  end

  test "formatted_context_window for thousands" do
    model = build(:ai_model, context_window: 128_000)
    assert_equal "128K", model.formatted_context_window
  end

  test "formatted_context_window for nil" do
    model = build(:ai_model, context_window: nil)
    assert_nil model.formatted_context_window
  end

  test "formatted_max_output for thousands" do
    model = build(:ai_model, max_output_tokens: 8192)
    assert_equal "8K", model.formatted_max_output
  end

  test "formatted_max_output for nil" do
    model = build(:ai_model, max_output_tokens: nil)
    assert_nil model.formatted_max_output
  end

  test "published scope" do
    published = create(:ai_model, published: true)
    create(:ai_model, published: false)
    assert_includes AiModel.published, published
  end

  test "active scope" do
    active = create(:ai_model, status: "active")
    create(:ai_model, status: "deprecated")
    assert_includes AiModel.active, active
  end

  test "by_provider scope" do
    openai = create(:ai_model, provider: "OpenAI")
    create(:ai_model, provider: "Anthropic")
    assert_includes AiModel.by_provider("OpenAI"), openai
  end

  test "by_family scope" do
    gpt4 = create(:ai_model, family: "GPT-4")
    create(:ai_model, family: "Claude 3.5")
    assert_includes AiModel.by_family("GPT-4"), gpt4
  end

  test "validates provider inclusion" do
    model = build(:ai_model, provider: "UnknownProvider")
    assert_not model.valid?
    assert_includes model.errors[:provider], "is not included in the list"
  end

  test "validates status inclusion" do
    model = build(:ai_model, status: "unknown")
    assert_not model.valid?
    assert_includes model.errors[:status], "is not included in the list"
  end

  test "validates URL format rejects invalid URLs" do
    model = build(:ai_model, website_url: "javascript:alert(1)")
    assert_not model.valid?
    assert_includes model.errors[:website_url], "must be a valid HTTP/HTTPS URL"
  end

  test "validates URL format accepts valid HTTP URLs" do
    model = build(:ai_model, website_url: "https://example.com")
    model.valid?
    assert_empty model.errors[:website_url]
  end

  test "validates input_per_1m_tokens is non-negative" do
    model = build(:ai_model, input_per_1m_tokens: -1)
    assert_not model.valid?
  end

  test "validates output_per_1m_tokens is non-negative" do
    model = build(:ai_model, output_per_1m_tokens: -1)
    assert_not model.valid?
  end

  test "validates context_window is positive" do
    model = build(:ai_model, context_window: 0)
    assert_not model.valid?
  end

  test "validates max_output_tokens is positive" do
    model = build(:ai_model, max_output_tokens: 0)
    assert_not model.valid?
  end

  # Sync-related tests

  test "has_many sync_changes" do
    model = create(:ai_model)
    change = create(:ai_model_change, ai_model: model)
    assert_includes model.sync_changes, change
  end

  test "syncable scope returns models with sync_enabled" do
    syncable = create(:ai_model, sync_enabled: true)
    create(:ai_model, sync_enabled: false)
    assert_includes AiModel.syncable, syncable
  end

  test "stale scope returns models not synced recently" do
    stale = create(:ai_model, last_synced_at: 2.days.ago)
    fresh = create(:ai_model, last_synced_at: 1.hour.ago)
    never_synced = create(:ai_model, last_synced_at: nil)

    assert_includes AiModel.stale(24), stale
    assert_includes AiModel.stale(24), never_synced
    assert_not_includes AiModel.stale(24), fresh
  end

  test "diff_with returns changed fields" do
    model = create(:ai_model, input_per_1m_tokens: 5.0, output_per_1m_tokens: 10.0)

    diff = model.diff_with(input_per_1m_tokens: 3.0, output_per_1m_tokens: 10.0)

    assert_equal 1, diff.keys.length
    assert_equal({ old: BigDecimal("5.0"), new: 3.0 }, diff["input_per_1m_tokens"])
  end

  test "diff_with ignores nil values in new data" do
    model = create(:ai_model, input_per_1m_tokens: 5.0)

    diff = model.diff_with(input_per_1m_tokens: nil)

    assert_empty diff
  end

  test "diff_with handles string and symbol keys" do
    model = create(:ai_model, input_per_1m_tokens: 5.0)

    diff1 = model.diff_with(input_per_1m_tokens: 3.0)
    diff2 = model.diff_with("input_per_1m_tokens" => 3.0)

    assert_equal 1, diff1.keys.length
    assert_equal 1, diff2.keys.length
  end

  test "apply_sync_update! updates model and creates change record" do
    model = create(:ai_model, input_per_1m_tokens: 5.0, output_per_1m_tokens: 10.0)

    assert_difference "AiModelChange.count", 1 do
      result = model.apply_sync_update!(
        { input_per_1m_tokens: 3.0 },
        source: "openrouter"
      )
      assert result
    end

    model.reload
    assert_equal 3.0, model.input_per_1m_tokens.to_f
    assert_not_nil model.last_synced_at
    assert_equal "openrouter", model.sync_source

    change = model.sync_changes.last
    assert_equal "pricing_change", change.change_type
    assert_equal "openrouter", change.source
  end

  test "apply_sync_update! returns false when no changes" do
    model = create(:ai_model, input_per_1m_tokens: 5.0)

    assert_no_difference "AiModelChange.count" do
      result = model.apply_sync_update!(
        { input_per_1m_tokens: 5.0 },
        source: "openrouter"
      )
      assert_not result
    end
  end

  test "apply_sync_update! sets correct change_type for deprecation" do
    model = create(:ai_model, status: "active")

    model.apply_sync_update!({ status: "deprecated" }, source: "manual")

    change = model.sync_changes.last
    assert_equal "deprecated", change.change_type
  end

  test "apply_sync_update! sets correct change_type for capability changes" do
    model = create(:ai_model, supports_vision: false)

    model.apply_sync_update!({ supports_vision: true }, source: "manual")

    change = model.sync_changes.last
    assert_equal "capability_change", change.change_type
  end

  test "apply_sync_update! stores confidence for AI-extracted data" do
    model = create(:ai_model, input_per_1m_tokens: 5.0)

    model.apply_sync_update!(
      { input_per_1m_tokens: 3.0 },
      source: "ai_extracted",
      confidence: 0.75
    )

    change = model.sync_changes.last
    assert_equal 0.75, change.confidence
  end
end
