# frozen_string_literal: true

class SafetyScore < ApplicationRecord
  belongs_to :agent

  VALID_BADGES = %w[ 🟢 🟡 🔴 ].freeze

  validates :overall_score, presence: true,
                            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :badge, presence: true, inclusion: { in: VALID_BADGES }
  validates :breakdown, presence: true

  scope :latest, -> { order(created_at: :desc) }
  scope :safe, -> { where(badge: "🟢") }
  scope :caution, -> { where(badge: "🟡") }
  scope :unsafe, -> { where(badge: "🔴") }

  # Webhook notifications for safety score changes
  after_create :notify_webhook_created
  after_update :notify_webhook_updated, if: :score_changed?

  def safe?
    badge == "🟢"
  end

  def caution?
    badge == "🟡"
  end

  def unsafe?
    badge == "🔴"
  end

  def critical_vulnerabilities
    breakdown&.dig("critical_vulnerabilities") || []
  end

  def critical_vulnerabilities?
    critical_vulnerabilities.any?
  end

  private

  def score_changed?
    saved_change_to_overall_score? || saved_change_to_badge?
  end

  def webhook_payload
    {
      agent_id: agent_id,
      agent_slug: agent.slug,
      agent_name: agent.name,
      safety_score_id: id,
      overall_score: overall_score,
      badge: badge,
      safety_level: safety_level_text,
      breakdown: breakdown,
      critical_vulnerabilities: critical_vulnerabilities,
      created_at: created_at&.iso8601
    }
  end

  def safety_level_text
    case badge
    when "🟢" then "safe"
    when "🟡" then "caution"
    when "🔴" then "unsafe"
    else "unknown"
    end
  end

  def notify_webhook_created
    WebhookService.trigger(agent, "safety_score.created", webhook_payload)
  rescue StandardError => e
    Rails.logger.error("[Webhook] Failed to trigger safety_score.created: #{e.message}")
  end

  def notify_webhook_updated
    WebhookService.trigger(agent, "safety_score.updated", webhook_payload)
  rescue StandardError => e
    Rails.logger.error("[Webhook] Failed to trigger safety_score.updated: #{e.message}")
  end
end
