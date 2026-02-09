# frozen_string_literal: true

class TelemetryAggregationJob < ApplicationJob
  queue_as :default

  # Aggregate telemetry events for a given agent and time period
  # @param agent_id [Integer] The agent to aggregate stats for
  # @param period [String] The period type: 'hourly', 'daily', 'weekly'
  def perform(agent_id, period = "daily")
    @agent = Agent.find(agent_id)
    @period = period
    @period_start, @period_end = calculate_period_bounds

    events = fetch_events
    return if events.empty?

    stats = calculate_stats(events)
    create_stat_record(stats)
  end

  private

  def calculate_period_bounds
    case @period
    when "hourly"
      [ 1.hour.ago.beginning_of_hour, 1.hour.ago.end_of_hour ]
    when "weekly"
      [ 1.week.ago.beginning_of_week, 1.week.ago.end_of_week ]
    else # daily
      [ 1.day.ago.beginning_of_day, 1.day.ago.end_of_day ]
    end
  end

  def fetch_events
    return [] unless defined?(TelemetryEvent)

    TelemetryEvent
      .where(agent_id: @agent.id)
      .where(created_at: @period_start..@period_end)
  end

  def calculate_stats(events)
    durations = events.filter_map(&:duration_ms)

    {
      total_events: events.count,
      success_rate: calculate_success_rate(events),
      avg_duration_ms: durations.any? ? (durations.sum.to_f / durations.size).round(2) : nil,
      p95_duration_ms: calculate_percentile(durations, 95),
      total_tokens: events.sum { |e| e.try(:tokens_used) || 0 },
      error_types: group_errors(events)
    }
  end

  def calculate_success_rate(events)
    return nil if events.empty?

    successful = events.count { |e| e.try(:success) || e.try(:status) == "success" }
    ((successful.to_f / events.size) * 100).round(2)
  end

  def calculate_percentile(values, percentile)
    return nil if values.empty?

    sorted = values.sort
    index = ((percentile.to_f / 100) * (sorted.size - 1)).ceil
    sorted[index]&.round(2)
  end

  def group_errors(events)
    failed_events = events.select { |e| e.try(:error_type).present? }
    return {} if failed_events.empty?

    failed_events
      .group_by { |e| e.error_type }
      .transform_values(&:count)
  end

  def create_stat_record(stats)
    AgentTelemetryStat.create!(
      agent: @agent,
      period_start: @period_start,
      period_end: @period_end,
      **stats
    )
  end
end
