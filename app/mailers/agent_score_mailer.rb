# frozen_string_literal: true

# Mailer for agent score-related notifications.
# Sends emails when agent scores decay below notification thresholds.
class AgentScoreMailer < ApplicationMailer
  default from: "evald.ai <notifications@evald.ai>"

  # Sends a warning email when an agent's score has decayed significantly
  #
  # @param user [User] The owner of the agent
  # @param agent [Agent] The agent whose score has decayed
  # @param agent_score [AgentScore] The agent score record
  # @param retention [Float] The percentage of original score retained (0-100)
  # @param threshold [Integer] The threshold that was crossed
  def decay_warning(user, agent, agent_score, retention, threshold)
    @user = user
    @agent = agent
    @agent_score = agent_score
    @retention = retention
    @threshold = threshold

    @current_score = agent_score.decayed_score
    @original_score = agent_score.score_at_eval
    @decay_percentage = (100 - retention).round(1)
    @re_evaluate_url = agent_url(@agent)

    mail(
      to: user.email,
      subject: "⚠️ #{agent.name} score has dropped to #{@current_score.round(1)} (#{threshold}% threshold)"
    )
  end
end
