# frozen_string_literal: true
FactoryBot.define do
  factory :agent_interaction do
    association :reporter_agent, factory: [:agent, :published, :with_score]
    association :target_agent, factory: [:agent, :published, :with_score]
    interaction_type { "delegation" }
    outcome { "Task completed successfully" }
    success { true }
  end
end
