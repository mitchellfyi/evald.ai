# frozen_string_literal: true

FactoryBot.define do
  factory :pending_agent do
    sequence(:name) { |n| "pending-agent-#{n}" }
    sequence(:github_url) { |n| "https://github.com/test-org/agent-#{n}" }
    description { "An AI agent for testing" }
    owner { "test-org" }
    stars { 200 }
    language { "Python" }
    license { "mit" }
    topics { ["ai-agent", "autonomous"] }
    confidence_score { 75 }
    status { "pending" }
    discovered_at { Time.current }

    trait :high_confidence do
      confidence_score { 85 }
    end

    trait :low_confidence do
      confidence_score { 55 }
    end

    trait :approved do
      status { "approved" }
      association :reviewed_by, factory: :user
      reviewed_at { Time.current }
    end

    trait :rejected do
      status { "rejected" }
      association :reviewed_by, factory: :user
      reviewed_at { Time.current }
      rejection_reason { "Not a real agent" }
    end
  end
end
