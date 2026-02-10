# frozen_string_literal: true

FactoryBot.define do
  factory :webhook_delivery do
    association :webhook_endpoint
    event_type { "score.created" }
    status { "pending" }
    payload { { agent_id: 1, score: 85.0 } }
    attempt_count { 0 }

    trait :delivering do
      status { "delivering" }
      attempt_count { 1 }
    end

    trait :delivered do
      status { "delivered" }
      attempt_count { 1 }
      response_code { 200 }
      delivered_at { Time.current }
    end

    trait :failed do
      status { "failed" }
      attempt_count { 5 }
      error_message { "Connection refused" }
    end

    trait :retryable do
      status { "pending" }
      attempt_count { 2 }
      next_retry_at { 1.minute.ago }
    end
  end
end
