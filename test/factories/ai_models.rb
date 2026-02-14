# frozen_string_literal: true

FactoryBot.define do
  factory :ai_model do
    sequence(:name) { |n| "Model #{n}" }
    sequence(:slug) { |n| "model-#{n}" }
    provider { "OpenAI" }
    published { true }
    status { "active" }

    trait :with_pricing do
      input_per_1m_tokens { 3.0 }
      output_per_1m_tokens { 15.0 }
    end

    trait :with_capabilities do
      context_window { 200_000 }
      max_output_tokens { 8192 }
      supports_vision { true }
      supports_function_calling { true }
      supports_json_mode { true }
      supports_streaming { true }
    end

    trait :unpublished do
      published { false }
    end

    trait :deprecated do
      status { "deprecated" }
    end

    trait :anthropic do
      provider { "Anthropic" }
    end

    trait :google do
      provider { "Google" }
    end
  end
end
