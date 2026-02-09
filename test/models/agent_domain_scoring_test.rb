# frozen_string_literal: true

require "test_helper"

class AgentDomainScoringTest < ActiveSupport::TestCase
  setup do
    @agent = agents(:claude)
  end

  test "DOMAINS constant matches EvalTask categories" do
    assert_equal %w[coding research workflow], Agent::DOMAINS
  end

  test "domain_scores returns empty hash when no domain evals" do
    assert_equal({}, @agent.domain_scores)
  end

  test "domain_confidence returns insufficient for zero evals" do
    assert_equal "insufficient", @agent.domain_confidence("coding")
  end

  test "domain_confidence returns low for 1-2 evals" do
    @agent.coding_evals_count = 1
    assert_equal "low", @agent.domain_confidence("coding")

    @agent.coding_evals_count = 2
    assert_equal "low", @agent.domain_confidence("coding")
  end

  test "domain_confidence returns medium for 3-5 evals" do
    @agent.coding_evals_count = 3
    assert_equal "medium", @agent.domain_confidence("coding")

    @agent.coding_evals_count = 5
    assert_equal "medium", @agent.domain_confidence("coding")
  end

  test "domain_confidence returns high for 6+ evals" do
    @agent.coding_evals_count = 6
    assert_equal "high", @agent.domain_confidence("coding")

    @agent.coding_evals_count = 100
    assert_equal "high", @agent.domain_confidence("coding")
  end

  test "domain_scores includes score, confidence, and evals_run" do
    @agent.coding_score = 85.5
    @agent.coding_evals_count = 4

    scores = @agent.domain_scores
    assert_equal 85.5, scores["coding"][:score]
    assert_equal "medium", scores["coding"][:confidence]
    assert_equal 4, scores["coding"][:evals_run]
  end

  test "effective_domains returns target_domains if set" do
    @agent.target_domains = %w[coding research]
    assert_equal %w[coding research], @agent.effective_domains
  end

  test "effective_domains infers from eval history when not set" do
    @agent.target_domains = []
    @agent.coding_evals_count = 5
    @agent.research_evals_count = 0
    @agent.workflow_evals_count = 2

    assert_equal %w[coding workflow], @agent.effective_domains
  end

  test "detect_primary_domain returns domain with most evals" do
    @agent.coding_evals_count = 10
    @agent.research_evals_count = 3
    @agent.workflow_evals_count = 5

    assert_equal "coding", @agent.detect_primary_domain
  end

  test "detect_primary_domain uses score as tiebreaker" do
    @agent.coding_evals_count = 5
    @agent.research_evals_count = 5
    @agent.coding_score = 80
    @agent.research_score = 90

    assert_equal "research", @agent.detect_primary_domain
  end

  test "domain_weighted_score weights by eval count" do
    @agent.target_domains = %w[coding research]
    @agent.coding_score = 90
    @agent.coding_evals_count = 10
    @agent.research_score = 70
    @agent.research_evals_count = 2

    # coding: 90 * 10 = 900
    # research: 70 * 2 = 140
    # total_score = 1040, total_weight = 12
    # weighted_score = 1040 / 12 = 86.67
    expected = ((90 * 10 + 70 * 2).to_f / 12).round(2)
    assert_equal expected, @agent.domain_weighted_score
  end

  test "domain_weighted_score caps weight at 10" do
    @agent.target_domains = %w[coding]
    @agent.coding_score = 85
    @agent.coding_evals_count = 100 # Should be capped to 10

    # 85 * 10 / 10 = 85
    assert_equal 85.0, @agent.domain_weighted_score
  end

  test "domain_weighted_score returns nil when no domains" do
    @agent.target_domains = []
    assert_nil @agent.domain_weighted_score
  end

  test "by_domain scope filters by target_domains array" do
    @agent.update!(target_domains: %w[coding research])

    coding_agents = Agent.by_domain("coding")
    assert_includes coding_agents, @agent

    workflow_agents = Agent.by_domain("workflow")
    assert_not_includes workflow_agents, @agent
  end

  test "by_primary_domain scope filters correctly" do
    @agent.update!(primary_domain: "coding")

    coding_agents = Agent.by_primary_domain("coding")
    assert_includes coding_agents, @agent

    research_agents = Agent.by_primary_domain("research")
    assert_not_includes research_agents, @agent
  end
end
