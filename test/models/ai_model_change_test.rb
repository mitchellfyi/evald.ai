# frozen_string_literal: true

require "test_helper"

class AiModelChangeTest < ActiveSupport::TestCase
  def setup
    @model = create(:ai_model)
  end

  test "validates change_type presence and inclusion" do
    change = AiModelChange.new(ai_model: @model, source: "manual")
    assert_not change.valid?
    assert_includes change.errors[:change_type], "can't be blank"

    change.change_type = "invalid_type"
    assert_not change.valid?
    assert_includes change.errors[:change_type], "is not included in the list"

    change.change_type = "created"
    change.valid?
    assert_not change.errors[:change_type].any?
  end

  test "validates source presence and inclusion" do
    change = AiModelChange.new(ai_model: @model, change_type: "created")
    assert_not change.valid?
    assert_includes change.errors[:source], "can't be blank"

    change.source = "invalid_source"
    assert_not change.valid?
    assert_includes change.errors[:source], "is not included in the list"

    change.source = "openrouter"
    change.valid?
    assert_not change.errors[:source].any?
  end

  test "validates confidence range" do
    change = build(:ai_model_change, ai_model: @model, confidence: -0.1)
    assert_not change.valid?

    change.confidence = 1.5
    assert_not change.valid?

    change.confidence = 0.8
    assert change.valid?
  end

  test "scopes work correctly" do
    reviewed = create(:ai_model_change, ai_model: @model, reviewed: true)
    unreviewed = create(:ai_model_change, ai_model: @model, reviewed: false)
    low_confidence = create(:ai_model_change, ai_model: @model, reviewed: false, confidence: 0.5)

    assert_includes AiModelChange.reviewed, reviewed
    assert_not_includes AiModelChange.reviewed, unreviewed

    assert_includes AiModelChange.unreviewed, unreviewed
    assert_not_includes AiModelChange.unreviewed, reviewed

    assert_includes AiModelChange.needs_review, low_confidence
    assert_not_includes AiModelChange.needs_review, reviewed
  end

  test "significant_pricing_change detects large changes" do
    change = build(:ai_model_change,
                   ai_model: @model,
                   change_type: "pricing_change",
                   old_values: { "input_per_1m_tokens" => 10.0, "output_per_1m_tokens" => 20.0 },
                   new_values: { "input_per_1m_tokens" => 15.0, "output_per_1m_tokens" => 20.0 })

    assert change.significant_pricing_change? # 50% increase

    change.new_values = { "input_per_1m_tokens" => 11.0, "output_per_1m_tokens" => 20.0 }
    assert_not change.significant_pricing_change? # 10% increase
  end

  test "summary generates appropriate messages" do
    change = build(:ai_model_change, ai_model: @model, change_type: "created")
    assert_match(/New model added/, change.summary)

    change.change_type = "pricing_change"
    assert_match(/Pricing updated/, change.summary)

    change.change_type = "deprecated"
    assert_match(/Model deprecated/, change.summary)
  end
end
