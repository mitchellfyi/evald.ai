# frozen_string_literal: true

FactoryBot.define do
  factory :tag do
    sequence(:name) { |n| "Tag #{n}" }

    trait :with_description do
      description { "A test tag description" }
    end
  end
end
