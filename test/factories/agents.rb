FactoryBot.define do
  factory :agent do
    sequence(:name) { |n| "agent-#{n}" }
    sequence(:slug) { |n| "agent-#{n}" }
    description { "A test agent" }
    repo_url { "https://github.com/test/agent" }
    category { "general" }
    published { false }
    featured { false }
    claim_status { "unclaimed" }
    decay_rate { "standard" }

    trait :published do
      published { true }
    end

    trait :featured do
      featured { true }
    end

    trait :claimed do
      claim_status { "claimed" }
      association :claimed_by_user, factory: :user
    end

    trait :verified do
      claim_status { "verified" }
      association :claimed_by_user, factory: :user
    end

    trait :with_score do
      score { 75.0 }
      score_at_eval { 75.0 }
      last_verified_at { 1.day.ago }
    end
  end
end
