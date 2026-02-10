# frozen_string_literal: true

FactoryBot.define do
  factory :agent_tag do
    association :agent
    association :tag
  end
end
