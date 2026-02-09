# frozen_string_literal: true

class AgentTelemetryStat < ApplicationRecord
  belongs_to :agent

  validates :period_start, presence: true
  validates :period_end, presence: true
  validates :total_events, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :success_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
  validates :avg_duration_ms, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :p95_duration_ms, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :total_tokens, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  validate :period_end_after_start

  scope :for_period, ->(period_type) {
    case period_type
    when :hourly
      where("period_end - period_start <= ?", 1.hour)
    when :daily
      where("period_end - period_start > ? AND period_end - period_start <= ?", 1.hour, 1.day)
    when :weekly
      where("period_end - period_start > ?", 1.day)
    end
  }

  scope :recent, -> { order(period_end: :desc) }

  private

  def period_end_after_start
    return unless period_start && period_end

    if period_end <= period_start
      errors.add(:period_end, "must be after period_start")
    end
  end
end
