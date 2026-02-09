# frozen_string_literal: true

FactoryBot.define do
  factory :notification_preference do
    association :user
    association :agent
    score_changes { true }
    new_eval_results { true }
    comparison_mentions { false }
    email_enabled { true }
  end
end
