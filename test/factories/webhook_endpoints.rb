# frozen_string_literal: true

FactoryBot.define do
  factory :webhook_endpoint do
    association :agent
    sequence(:url) { |n| "https://example.com/webhooks/#{n}" }
    events { ["score.created"] }
    enabled { true }
    secret { SecureRandom.hex(32) }
    failure_count { 0 }

    trait :disabled do
      enabled { false }
      disabled_at { Time.current }
    end

    trait :failing do
      failure_count { 4 }
    end
  end
end
