# frozen_string_literal: true

class SecurityScan < ApplicationRecord
  belongs_to :agent

  SCAN_TYPES = %w[full dependencies code secrets container].freeze
  SEVERITIES = %w[critical high medium low unknown].freeze

  validates :scan_type, presence: true, inclusion: { in: SCAN_TYPES }
  validates :scanned_at, presence: true
  validates :findings, presence: true
  validates :severity_counts, presence: true

  scope :passed, -> { where(passed: true) }
  scope :failed, -> { where(passed: false) }
  scope :recent, -> { order(scanned_at: :desc) }
  scope :by_type, ->(type) { where(scan_type: type) }

  def total_findings
    findings&.size || 0
  end

  def critical_count
    severity_counts&.dig("critical") || 0
  end

  def high_count
    severity_counts&.dig("high") || 0
  end

  def findings_by_type
    return {} unless findings

    findings.group_by { |f| f["type"] }
  end

  def status_label
    passed? ? "passed" : "failed"
  end
end
