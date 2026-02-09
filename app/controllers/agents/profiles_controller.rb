module Agents
  class ProfilesController < ApplicationController
    def show
      @agent = Agent.published.find_by!(slug: params[:agent_id])
      @score_breakdown = build_score_breakdown
      @version_history = @agent.agent_scores.order(created_at: :desc).limit(20)
      @claim_request = @agent.claimed? ? nil : ClaimRequest.new
    end

    private

    def build_score_breakdown
      {
        current_score: @agent.decayed_score,
        score_at_eval: @agent.score_at_eval,
        last_verified_at: @agent.last_verified_at,
        tier0: {
          weight: 0.4,
          score: @agent.compute_tier0_score,
          signals: @agent.tier0_summary
        },
        tier1: {
          weight: 0.6,
          score: @agent.compute_tier1_score,
          metrics: @agent.tier1_summary
        },
        decay: {
          rate: @agent.decay_rate || "standard",
          days_since_eval: @agent.last_verified_at ? ((Time.current - @agent.last_verified_at) / 1.day).round : nil
        }
      }
    end
  end
end
