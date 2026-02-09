# frozen_string_literal: true

# Scheduled job to refresh Tier 0 scores for all agents
# Runs once per day, processing agents that haven't been evaluated recently
class Tier0RefreshJob < ApplicationJob
  queue_as :low

  # Process agents in batches to avoid overwhelming the system
  BATCH_SIZE = 50
  MIN_HOURS_BETWEEN_EVALS = 23 # Slightly less than 24h to handle timing drift

  def perform(batch_offset = 0)
    agents_to_eval = agents_needing_refresh.offset(batch_offset).limit(BATCH_SIZE)

    return if agents_to_eval.empty?

    agents_to_eval.find_each do |agent|
      Tier0EvaluationJob.perform_later(agent.id)

      # Small delay between queueing to spread load
      sleep(0.1)
    end

    # Queue next batch if there are more agents
    remaining = agents_needing_refresh.count - batch_offset - BATCH_SIZE
    if remaining > 0
      Tier0RefreshJob.set(wait: 5.minutes).perform_later(batch_offset + BATCH_SIZE)
    end

    Rails.logger.info "[Tier0Refresh] Queued #{agents_to_eval.count} agents, #{remaining} remaining"
  end

  private

  def agents_needing_refresh
    # Find agents that:
    # 1. Have a GitHub repo URL
    # 2. Haven't been evaluated in the last 23 hours OR have never been evaluated
    Agent.where.not(repo_url: [nil, ""])
         .left_joins(:agent_scores)
         .where(agent_scores: { id: nil })
         .or(
           Agent.where.not(repo_url: [nil, ""])
                .left_joins(:agent_scores)
                .where("agent_scores.tier = 0")
                .where("agent_scores.evaluated_at < ?", MIN_HOURS_BETWEEN_EVALS.hours.ago)
         )
         .distinct
         .order(stars: :desc) # Prioritize popular agents
  end
end
