# frozen_string_literal: true
require "test_helper"

class AgentConfidenceTest < ActiveSupport::TestCase
  test "insufficient confidence when no tier0 data" do
    agent = create(:agent)
    assert_equal "insufficient", agent.confidence_level
  end

  test "low confidence with tier0 only" do
    agent = create(:agent,
      tier0_repo_health: 80.0,
      tier0_documentation: 70.0,
      tier0_bus_factor: 60.0)
    assert_equal "low", agent.confidence_level
  end

  test "medium confidence with tier0 and partial tier1" do
    agent = create(:agent,
      tier0_repo_health: 80.0,
      tier0_documentation: 70.0,
      tier1_accuracy: 0.85,
      tier1_completion_rate: 0.90)
    assert_equal "medium", agent.confidence_level
  end

  test "medium confidence with tier0 and recent tier0 eval" do
    agent = create(:agent,
      tier0_repo_health: 80.0,
      tier0_documentation: 70.0)
    create(:evaluation, :completed, agent: agent, tier: "tier0", created_at: 10.days.ago)
    assert_equal "medium", agent.confidence_level
  end

  test "high confidence with complete tier0 and tier1 data, multiple runs, recent eval" do
    agent = create(:agent,
      tier0_repo_health: 80.0,
      tier0_documentation: 70.0,
      tier0_bus_factor: 60.0,
      tier0_dependency_risk: 75.0,
      tier0_community: 65.0,
      tier0_license: 90.0,
      tier0_maintenance: 70.0,
      tier1_accuracy: 0.85,
      tier1_completion_rate: 0.90,
      tier1_cost_efficiency: 0.80,
      tier1_scope_discipline: 0.75,
      tier1_safety: 0.88,
      last_verified_at: 5.days.ago)
    task = create(:eval_task)
    create(:eval_run, :completed, agent: agent, eval_task: task, metrics: { "score" => 85 })
    create(:eval_run, :completed, agent: agent, eval_task: task, metrics: { "score" => 87 })
    assert_equal "high", agent.confidence_level
  end

  test "not high confidence without recent eval" do
    agent = create(:agent,
      tier0_repo_health: 80.0,
      tier1_accuracy: 0.85,
      tier1_completion_rate: 0.90,
      tier1_cost_efficiency: 0.80,
      tier1_scope_discipline: 0.75,
      tier1_safety: 0.88,
      last_verified_at: 60.days.ago)
    task = create(:eval_task)
    create(:eval_run, :completed, agent: agent, eval_task: task, metrics: { "score" => 85 })
    create(:eval_run, :completed, agent: agent, eval_task: task, metrics: { "score" => 87 })
    refute_equal "high", agent.confidence_level
  end

  test "confidence_factors returns detailed breakdown" do
    agent = create(:agent, tier0_repo_health: 80.0)
    factors = agent.confidence_factors

    assert factors.key?(:level)
    assert factors.key?(:has_tier0)
    assert factors.key?(:has_tier1)
    assert factors.key?(:tier1_run_count)
    assert factors.key?(:recent_eval)
    assert factors.key?(:low_variance)
  end

  test "confidence_factors detects low variance" do
    agent = create(:agent, tier0_repo_health: 80.0)
    task = create(:eval_task)
    create(:eval_run, :completed, agent: agent, eval_task: task, metrics: { "score" => 85 })
    create(:eval_run, :completed, agent: agent, eval_task: task, metrics: { "score" => 86 })
    factors = agent.confidence_factors

    assert factors[:low_variance], "Scores 85 and 86 should have low variance"
  end

  test "confidence_factors detects high variance" do
    agent = create(:agent, tier0_repo_health: 80.0)
    task = create(:eval_task)
    create(:eval_run, :completed, agent: agent, eval_task: task, metrics: { "score" => 50 })
    create(:eval_run, :completed, agent: agent, eval_task: task, metrics: { "score" => 95 })
    factors = agent.confidence_factors

    refute factors[:low_variance], "Scores 50 and 95 should have high variance"
  end

  test "high variance prevents high confidence even with complete data" do
    agent = create(:agent,
      tier0_repo_health: 80.0,
      tier0_documentation: 70.0,
      tier0_bus_factor: 60.0,
      tier0_dependency_risk: 75.0,
      tier0_community: 65.0,
      tier0_license: 90.0,
      tier0_maintenance: 70.0,
      tier1_accuracy: 0.85,
      tier1_completion_rate: 0.90,
      tier1_cost_efficiency: 0.80,
      tier1_scope_discipline: 0.75,
      tier1_safety: 0.88,
      last_verified_at: 5.days.ago)
    task = create(:eval_task)
    create(:eval_run, :completed, agent: agent, eval_task: task, metrics: { "score" => 50 })
    create(:eval_run, :completed, agent: agent, eval_task: task, metrics: { "score" => 95 })

    assert_equal "medium", agent.confidence_level,
      "High variance should prevent high confidence, falling back to medium"
  end

  test "tier0 with zero-value score is still detected as having data" do
    agent = create(:agent, tier0_repo_health: 0.0)
    assert_equal "low", agent.confidence_level,
      "Zero-value tier0 score should still count as having tier0 data"
  end
end
