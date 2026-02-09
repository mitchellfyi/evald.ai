# frozen_string_literal: true

class Tier2EvaluationJob < ApplicationJob
  queue_as :default

  def perform(agent_id)
    agent = Agent.find(agent_id)
    Tier2::SafetyScoringEngine.new(agent).evaluate
  end
end
