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

    trait :ai_reviewed do
      ai_reviewed_at { Time.current }
      ai_classification { "agent" }
      ai_confidence { 0.85 }
      ai_categories { ["coding"] }
      ai_description { "An AI coding agent" }
      ai_capabilities { ["code_generation", "bug_fixing"] }
      ai_reasoning { "Clear evidence of autonomous behavior" }
      is_agent { true }
    end

    trait :ai_classified_as_sdk do
      ai_reviewed_at { Time.current }
      ai_classification { "sdk" }
      ai_confidence { 0.9 }
      ai_categories { [] }
      ai_description { "A SDK for building AI agents" }
      ai_capabilities { [] }
      ai_reasoning { "This is a library for building agents, not an agent itself" }
      is_agent { false }
    end

    trait :ai_needs_review do
      ai_reviewed_at { Time.current }
      ai_classification { "agent" }
      ai_confidence { 0.65 }
      ai_categories { ["coding"] }
      ai_description { "Possibly an AI agent" }
      ai_capabilities { ["code_generation"] }
      ai_reasoning { "Uncertain classification - needs human review" }
      is_agent { true }
    end
  end
end
