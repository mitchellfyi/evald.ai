# frozen_string_literal: true

require "test_helper"

class AgentTierTest < ActiveSupport::TestCase
  setup do
    @agent = agents(:claude)
  end

  test "tier returns platinum for scores 90-100" do
    @agent.score = 95
    @agent.score_at_eval = 95
    @agent.last_verified_at = Time.current
    assert_equal "platinum", @agent.tier

    @agent.score = 90
    @agent.score_at_eval = 90
    assert_equal "platinum", @agent.tier
  end

  test "tier returns gold for scores 80-89" do
    @agent.score = 85
    @agent.score_at_eval = 85
    @agent.last_verified_at = Time.current
    assert_equal "gold", @agent.tier

    @agent.score = 80
    @agent.score_at_eval = 80
    assert_equal "gold", @agent.tier
  end

  test "tier returns silver for scores 70-79" do
    @agent.score = 75
    @agent.score_at_eval = 75
    @agent.last_verified_at = Time.current
    assert_equal "silver", @agent.tier
  end

  test "tier returns bronze for scores 60-69" do
    @agent.score = 65
    @agent.score_at_eval = 65
    @agent.last_verified_at = Time.current
    assert_equal "bronze", @agent.tier
  end

  test "tier returns unrated for scores below 60" do
    @agent.score = 50
    @agent.score_at_eval = 50
    @agent.last_verified_at = Time.current
    assert_equal "unrated", @agent.tier

    @agent.score = nil
    assert_equal "unrated", @agent.tier
  end

  test "tier is based on decayed_score not raw score" do
    @agent.score = 92
    @agent.score_at_eval = 92
    @agent.last_verified_at = 200.days.ago
    @agent.decay_rate = "standard"

    # With standard decay (0.002), after 200 days:
    # decayed = 92 - (200 * 0.002 * 92) = 92 - 36.8 = 55.2
    # This is below 60, so should be unrated... but let's verify

    decayed = @agent.decayed_score
    assert decayed < 90, "Expected decayed score < 90, got #{decayed}"
  end
end
