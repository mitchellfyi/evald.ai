# frozen_string_literal: true

require "test_helper"

class AgentTelemetryStatTest < ActiveSupport::TestCase
  test "factory creates valid agent_telemetry_stat" do
    stat = build(:agent_telemetry_stat)
    assert stat.valid?
  end

  test "requires period_start" do
    stat = build(:agent_telemetry_stat, period_start: nil)
    refute stat.valid?
    assert_includes stat.errors[:period_start], "can't be blank"
  end

  test "requires period_end" do
    stat = build(:agent_telemetry_stat, period_end: nil)
    refute stat.valid?
    assert_includes stat.errors[:period_end], "can't be blank"
  end

  test "period_end must be after period_start" do
    stat = build(:agent_telemetry_stat, period_start: Time.current, period_end: 1.hour.ago)
    refute stat.valid?
    assert_includes stat.errors[:period_end], "must be after period_start"
  end

  test "total_events must be a non-negative integer" do
    stat = build(:agent_telemetry_stat, total_events: -1)
    refute stat.valid?
    assert_includes stat.errors[:total_events], "must be greater than or equal to 0"
  end

  test "total_events must be an integer" do
    stat = build(:agent_telemetry_stat, total_events: 1.5)
    refute stat.valid?
    assert_includes stat.errors[:total_events], "must be an integer"
  end

  test "total_events allows nil" do
    stat = build(:agent_telemetry_stat, total_events: nil)
    assert stat.valid?
  end

  test "success_rate must be between 0 and 100" do
    stat = build(:agent_telemetry_stat, success_rate: -1)
    refute stat.valid?

    stat = build(:agent_telemetry_stat, success_rate: 101)
    refute stat.valid?

    stat = build(:agent_telemetry_stat, success_rate: 50)
    assert stat.valid?
  end

  test "success_rate allows nil" do
    stat = build(:agent_telemetry_stat, success_rate: nil)
    assert stat.valid?
  end

  test "avg_duration_ms must be non-negative" do
    stat = build(:agent_telemetry_stat, avg_duration_ms: -1)
    refute stat.valid?
    assert_includes stat.errors[:avg_duration_ms], "must be greater than or equal to 0"
  end

  test "avg_duration_ms allows nil" do
    stat = build(:agent_telemetry_stat, avg_duration_ms: nil)
    assert stat.valid?
  end

  test "p95_duration_ms must be non-negative" do
    stat = build(:agent_telemetry_stat, p95_duration_ms: -1)
    refute stat.valid?
    assert_includes stat.errors[:p95_duration_ms], "must be greater than or equal to 0"
  end

  test "p95_duration_ms allows nil" do
    stat = build(:agent_telemetry_stat, p95_duration_ms: nil)
    assert stat.valid?
  end

  test "total_tokens must be a non-negative integer" do
    stat = build(:agent_telemetry_stat, total_tokens: -1)
    refute stat.valid?

    stat = build(:agent_telemetry_stat, total_tokens: 1.5)
    refute stat.valid?
  end

  test "total_tokens allows nil" do
    stat = build(:agent_telemetry_stat, total_tokens: nil)
    assert stat.valid?
  end

  test "recent scope orders by period_end descending" do
    old = create(:agent_telemetry_stat, period_start: 3.hours.ago, period_end: 2.hours.ago)
    recent = create(:agent_telemetry_stat, period_start: 1.hour.ago, period_end: Time.current)

    result = AgentTelemetryStat.recent
    assert_equal recent, result.first
    assert_equal old, result.last
  end

  test "for_period scope responds to period types" do
    assert_respond_to AgentTelemetryStat, :for_period
  end

  test "belongs to agent" do
    agent = create(:agent)
    stat = create(:agent_telemetry_stat, agent: agent)
    assert_equal agent, stat.agent
  end
end
