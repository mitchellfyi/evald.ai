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
end
