# frozen_string_literal: true

# Calculates decayed scores based on time elapsed since evaluation.
# Scores decay exponentially based on the configured decay rate.
class ScoreDecayCalculator
  # Decay rate factors per day
  # These represent the daily retention rate (how much score is retained each day)
  DECAY_RATES = {
    "slow" => 0.999,     # ~0.1% decay per day, ~3% per month
    "standard" => 0.995, # ~0.5% decay per day, ~14% per month
    "fast" => 0.990      # ~1% decay per day, ~26% per month
  }.freeze

  # Default decay rate if not specified
  DEFAULT_RATE = "standard"

  class << self
    # Calculates the current decayed score for an agent score
    #
    # @param agent_score [AgentScore] The agent score record
    # @return [Float] The decayed score value
    def calculate_current_score(agent_score)
      return agent_score.overall_score if agent_score.score_at_eval.blank?

      base_score = agent_score.score_at_eval.to_f
      days_elapsed = days_since_eval(agent_score)
      rate_factor = decay_rate_factor(agent_score.decay_rate)

      # Apply exponential decay: score = base_score * (rate ^ days)
      decayed = base_score * (rate_factor**days_elapsed)

      # Clamp to valid range [0, 100]
      decayed.clamp(0.0, 100.0).round(2)
    end

    # Returns the decay rate factor for a given rate name
    #
    # @param rate [String] The decay rate name (slow, standard, fast)
    # @return [Float] The daily retention factor
    def decay_rate_factor(rate)
      DECAY_RATES[rate.to_s] || DECAY_RATES[DEFAULT_RATE]
    end

    # Calculates the percentage of original score remaining
    #
    # @param agent_score [AgentScore] The agent score record
    # @return [Float] Percentage of original score (0-100)
    def score_retention_percentage(agent_score)
      return 100.0 if agent_score.score_at_eval.blank? || agent_score.score_at_eval.zero?

      current = calculate_current_score(agent_score)
      ((current / agent_score.score_at_eval.to_f) * 100).round(2)
    end

    # Estimates when the score will drop below a threshold
    #
    # @param agent_score [AgentScore] The agent score record
    # @param threshold [Float] The score threshold (default: 70.0)
    # @return [DateTime, nil] Estimated date or nil if already below threshold
    def estimated_threshold_date(agent_score, threshold: 70.0)
      return nil if agent_score.score_at_eval.blank?

      base_score = agent_score.score_at_eval.to_f
      return nil if base_score <= threshold

      rate_factor = decay_rate_factor(agent_score.decay_rate)
      reference_date = agent_score.last_verified_at || agent_score.evaluated_at

      return nil if reference_date.blank?

      # Solve for days: threshold = base_score * (rate ^ days)
      # days = log(threshold / base_score) / log(rate)
      days_to_threshold = Math.log(threshold / base_score) / Math.log(rate_factor)

      reference_date + days_to_threshold.days
    end

    private

    def days_since_eval(agent_score)
      reference_date = agent_score.last_verified_at || agent_score.evaluated_at
      return 0 if reference_date.blank?

      ((Time.current - reference_date) / 1.day).to_f.clamp(0, Float::INFINITY)
    end
  end
end
