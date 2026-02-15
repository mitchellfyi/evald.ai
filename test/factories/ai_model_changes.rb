# frozen_string_literal: true

FactoryBot.define do
  factory :ai_model_change do
    association :ai_model
    change_type { "updated" }
    source { "openrouter" }
    old_values { { "input_per_1m_tokens" => 1.0 } }
    new_values { { "input_per_1m_tokens" => 2.0 } }
    confidence { 0.95 }
    reviewed { false }

    trait :created do
      change_type { "created" }
      old_values { {} }
      new_values { { "input_per_1m_tokens" => 2.0, "output_per_1m_tokens" => 4.0 } }
    end

    trait :pricing_change do
      change_type { "pricing_change" }
      old_values { { "input_per_1m_tokens" => 2.0, "output_per_1m_tokens" => 4.0 } }
      new_values { { "input_per_1m_tokens" => 1.5, "output_per_1m_tokens" => 3.0 } }
    end

    trait :deprecated do
      change_type { "deprecated" }
      old_values { { "status" => "active" } }
      new_values { { "status" => "deprecated" } }
    end

    trait :reviewed do
      reviewed { true }
    end

    trait :low_confidence do
      confidence { 0.5 }
    end

    trait :ai_extracted do
      source { "ai_extracted" }
      confidence { 0.7 }
    end
  end
end
