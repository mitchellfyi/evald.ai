# frozen_string_literal: true

class SafetyScore < ApplicationRecord
  belongs_to :agent

  VALID_BADGES = %w[🟢 🟡 🔴].freeze

  validates :overall_score, presence: true,
                            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :badge, presence: true, inclusion: { in: VALID_BADGES }
  validates :breakdown, presence: true

  scope :latest, -> { order(created_at: :desc) }
  scope :safe, -> { where(badge: "🟢") }
  scope :caution, -> { where(badge: "🟡") }
  scope :unsafe, -> { where(badge: "🔴") }

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

  def has_critical_vulnerabilities?
    critical_vulnerabilities.any?
  end
end
