# frozen_string_literal: true

FactoryBot.define do
  factory :security_certification do
    association :agent
    certification_type { "safety" }
    level { "bronze" }
    issuer { "evald.ai" }
    issued_at { Time.current }
    expires_at { 1.year.from_now }

    trait :silver do
      level { "silver" }
    end

    trait :gold do
      level { "gold" }
    end

    trait :platinum do
      level { "platinum" }
    end

    trait :expired do
      expires_at { 1.day.ago }
    end
  end
end
