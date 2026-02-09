# frozen_string_literal: true

# Job to notify agent owners when their scores have decayed significantly.
# Runs periodically to check for scores that need attention.
class ScoreDecayNotificationJob < ApplicationJob
  queue_as :default

  # Threshold at which to notify owners (percentage of original score retained)
  NOTIFICATION_THRESHOLDS = [ 90, 80, 70, 60, 50 ].freeze

  # Minimum days between notifications for the same agent
  NOTIFICATION_COOLDOWN_DAYS = 7

  def perform
    check_all_scores
  end

  private

  def check_all_scores
    AgentScore.current.includes(:agent).find_each do |agent_score|
      check_and_notify(agent_score)
    end
  end

  def check_and_notify(agent_score)
    return unless should_notify?(agent_score)

    retention = ScoreDecayCalculator.score_retention_percentage(agent_score)
    threshold = next_threshold_crossed(retention)

    return if threshold.nil?

    send_notification(agent_score, retention, threshold)
  end

  def should_notify?(agent_score)
    return false if agent_score.score_at_eval.blank?
    return false if recently_notified?(agent_score)

    true
  end

  def recently_notified?(agent_score)
    # Check if we've notified about this score recently
    # This would typically check a notifications table or similar
    # For now, we'll use next_eval_scheduled_at as a proxy
    return false if agent_score.next_eval_scheduled_at.blank?

    agent_score.next_eval_scheduled_at > Time.current
  end

  def next_threshold_crossed(retention)
    NOTIFICATION_THRESHOLDS.find { |threshold| retention <= threshold }
  end

  def send_notification(agent_score, retention, threshold)
    agent = agent_score.agent
    return unless agent.user.present?

    # Log the notification (email sending would be implemented separately)
    Rails.logger.info(
      "[ScoreDecayNotification] Agent '#{agent.name}' (ID: #{agent.id}) " \
      "score has decayed to #{retention.round(1)}% (threshold: #{threshold}%)"
    )

    # Mark that we've scheduled a re-evaluation
    agent_score.update(
      next_eval_scheduled_at: NOTIFICATION_COOLDOWN_DAYS.days.from_now
    )

    # TODO: Send actual email notification via ActionMailer
    # AgentScoreMailer.decay_warning(agent.user, agent, agent_score, retention).deliver_later
  end
end
