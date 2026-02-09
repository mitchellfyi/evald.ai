# frozen_string_literal: true
require "test_helper"

class Api::V1::AgentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @agent1 = create(:agent, :published, :with_score, name: "Alpha Agent", slug: "alpha-agent", category: "coding")
    @agent2 = create(:agent, :published, :with_score, name: "Beta Agent", slug: "beta-agent", category: "research", score: 85.0, score_at_eval: 85.0)
    @agent3 = create(:agent, :published, :with_score, name: "Gamma Agent", slug: "gamma-agent", category: "coding", score: 60.0, score_at_eval: 60.0)
    @unpublished = create(:agent, name: "Unpublished Agent", slug: "unpublished-agent")
  end

  # ============================================
  # GET /api/v1/agents (index)
  # ============================================

  test "index returns published agents ordered by score" do
    get api_v1_agents_url, as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert_kind_of Array, json
    assert_equal 3, json.size

    # Should be ordered by score descending
    scores = json.map { |a| a["score"] }
    assert_equal scores.sort.reverse, scores
  end

  test "index excludes unpublished agents" do
    get api_v1_agents_url, as: :json

    json = JSON.parse(response.body)
    slugs = json.map { |a| a["agent"] }

    assert_not_includes slugs, "unpublished-agent"
  end

  test "index filters by capability (category)" do
    get api_v1_agents_url, params: { capability: "coding" }, as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal 2, json.size
    json.each do |agent|
      assert_equal "coding", agent["category"]
    end
  end

  test "index filters by minimum score" do
    get api_v1_agents_url, params: { min_score: 70 }, as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal 2, json.size
    json.each do |agent|
      assert agent["score"] >= 70, "Agent score #{agent['score']} should be >= 70"
    end
  end

  test "index respects limit parameter" do
    get api_v1_agents_url, params: { limit: 2 }, as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal 2, json.size
  end

  test "index returns correct JSON structure" do
    get api_v1_agents_url, as: :json

    json = JSON.parse(response.body)
    first_agent = json.first

    assert first_agent.key?("agent"), "Should have 'agent' (slug)"
    assert first_agent.key?("name"), "Should have 'name'"
    assert first_agent.key?("category"), "Should have 'category'"
    assert first_agent.key?("score"), "Should have 'score'"
    assert first_agent.key?("confidence"), "Should have 'confidence'"
    assert first_agent.key?("last_verified"), "Should have 'last_verified'"
  end

  # ============================================
  # GET /api/v1/agents/:id (show)
  # ============================================

  test "show returns agent detail" do
    get api_v1_agent_url(@agent1.slug), as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal "alpha-agent", json["agent"]
    assert_equal "Alpha Agent", json["name"]
    assert_equal "coding", json["category"]
    assert json.key?("description")
    assert json.key?("builder")
    assert json.key?("score")
    assert json.key?("confidence")
    assert_includes Agent::CONFIDENCE_LEVELS, json["confidence"]
    assert json.key?("tier0")
    assert json.key?("tier1")
  end

  test "show returns 404 for unknown agent" do
    get api_v1_agent_url("nonexistent-agent"), as: :json

    assert_response :not_found
    json = JSON.parse(response.body)

    assert_equal "Not found", json["error"]
  end

  test "show returns 404 for unpublished agent" do
    get api_v1_agent_url(@unpublished.slug), as: :json

    assert_response :not_found
  end

  test "show returns complete builder information" do
    @agent1.update!(builder_name: "Test Builder", builder_url: "https://builder.test")
    get api_v1_agent_url(@agent1.slug), as: :json

    json = JSON.parse(response.body)

    assert_equal "Test Builder", json["builder"]["name"]
    assert_equal "https://builder.test", json["builder"]["url"]
  end

  # ============================================
  # GET /api/v1/agents/:id/score
  # ============================================

  test "score returns agent score data" do
    get score_api_v1_agent_url(@agent1.slug), as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal "alpha-agent", json["agent"]
    assert json.key?("score")
    assert json.key?("confidence")
    assert_includes Agent::CONFIDENCE_LEVELS, json["confidence"]
    assert json.key?("tier0")
    assert json.key?("tier1")
    assert json.key?("last_verified")
  end

  test "score returns 404 for unknown agent" do
    get score_api_v1_agent_url("nonexistent"), as: :json

    assert_response :not_found
  end

  # ============================================
  # GET /api/v1/agents/compare
  # ============================================

  test "compare returns multiple agents with recommendation" do
    get compare_api_v1_agents_url, params: { agents: "alpha-agent,beta-agent", task: "code review" }, as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal "code review", json["task"]
    assert_kind_of Array, json["agents"]
    assert_equal 2, json["agents"].size
    assert json.key?("recommendation")
  end

  test "compare recommends highest scoring agent" do
    get compare_api_v1_agents_url, params: { agents: "alpha-agent,beta-agent" }, as: :json

    json = JSON.parse(response.body)

    # beta-agent has score 85, alpha-agent has 75
    assert_equal "beta-agent", json["recommendation"]["recommended"]
  end

  test "compare limits to 5 agents" do
    # Create more agents
    6.times { |i| create(:agent, :published, slug: "extra-#{i}") }

    agents = "alpha-agent,beta-agent,gamma-agent,extra-0,extra-1,extra-2,extra-3"
    get compare_api_v1_agents_url, params: { agents: agents }, as: :json

    json = JSON.parse(response.body)
    # Should only process first 5 slugs
    assert json["agents"].size <= 5
  end

  test "compare ignores unknown agents gracefully" do
    get compare_api_v1_agents_url, params: { agents: "alpha-agent,nonexistent" }, as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal 1, json["agents"].size
  end

  # ============================================
  # GET /api/v1/agents/search
  # ============================================

  test "search returns matching agents by query" do
    get search_api_v1_agents_url, params: { q: "Alpha" }, as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal 1, json.size
    assert_equal "alpha-agent", json.first["agent"]
  end

  test "search filters by capability" do
    get search_api_v1_agents_url, params: { capability: "research" }, as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal 1, json.size
    assert_equal "beta-agent", json.first["agent"]
  end

  test "search filters by minimum score" do
    get search_api_v1_agents_url, params: { min_score: 80 }, as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal 1, json.size
    json.each do |agent|
      assert agent["score"] >= 80
    end
  end

  test "search combines multiple filters" do
    get search_api_v1_agents_url, params: { q: "Agent", capability: "coding", min_score: 70 }, as: :json

    assert_response :success
    json = JSON.parse(response.body)

    # Only alpha-agent is coding with score >= 70
    assert_equal 1, json.size
    assert_equal "alpha-agent", json.first["agent"]
  end

  test "search limits results to 20" do
    25.times { |i| create(:agent, :published, name: "Searchable #{i}", slug: "searchable-#{i}") }

    get search_api_v1_agents_url, params: { q: "Searchable" }, as: :json

    json = JSON.parse(response.body)
    assert json.size <= 20
  end

  test "search is case insensitive" do
    get search_api_v1_agents_url, params: { q: "ALPHA" }, as: :json

    json = JSON.parse(response.body)
    assert_equal 1, json.size
    assert_equal "alpha-agent", json.first["agent"]
  end

  # ============================================
  # Domain-Specific Scoring Tests
  # ============================================

  test "show includes domain_scores in response" do
    @agent1.update!(coding_score: 91, coding_evals_count: 5, primary_domain: "coding")

    get api_v1_agent_url(@agent1.slug), as: :json

    json = JSON.parse(response.body)
    assert json.key?("domain_scores")
    assert json.key?("primary_domain")
    assert_equal "coding", json["primary_domain"]

    coding_domain = json["domain_scores"]["coding"]
    assert_equal 91.0, coding_domain["score"]
    assert_equal "medium", coding_domain["confidence"]
    assert_equal 5, coding_domain["evals_run"]
  end

  test "score endpoint includes domain_scores" do
    @agent1.update!(coding_score: 85, coding_evals_count: 10)

    get score_api_v1_agent_url(@agent1.slug), as: :json

    json = JSON.parse(response.body)
    assert json.key?("domain_scores")
    assert_equal 85.0, json["domain_scores"]["coding"]["score"]
  end

  test "compare uses domain score when domain filter provided" do
    @agent1.update!(coding_score: 95, coding_evals_count: 10)
    @agent2.update!(coding_score: 80, coding_evals_count: 5)

    get compare_api_v1_agents_url, params: { agents: "alpha-agent,beta-agent", domain: "coding" }, as: :json

    json = JSON.parse(response.body)
    # alpha-agent should be recommended due to higher coding score
    assert_equal "alpha-agent", json["recommendation"]["recommended"]
    assert_includes json["recommendation"]["reason"], "Coding domain score"
  end

  test "compare includes domain_score when domain filter provided" do
    @agent1.update!(coding_score: 88, coding_evals_count: 3)

    get compare_api_v1_agents_url, params: { agents: "alpha-agent", domain: "coding" }, as: :json

    json = JSON.parse(response.body)
    agent = json["agents"].first
    assert_equal 88.0, agent["domain_score"]
    assert_equal "medium", agent["domain_confidence"]
  end

  test "search filters by domain" do
    @agent1.update!(target_domains: %w[coding research])
    @agent2.update!(target_domains: %w[research])

    get search_api_v1_agents_url, params: { domain: "coding" }, as: :json

    json = JSON.parse(response.body)
    slugs = json.map { |a| a["agent"] }
    assert_includes slugs, "alpha-agent"
    assert_not_includes slugs, "beta-agent"
  end

  test "search filters by primary_domain" do
    @agent1.update!(primary_domain: "coding")
    @agent2.update!(primary_domain: "research")

    get search_api_v1_agents_url, params: { primary_domain: "coding" }, as: :json

    json = JSON.parse(response.body)
    slugs = json.map { |a| a["agent"] }
    assert_includes slugs, "alpha-agent"
    assert_not_includes slugs, "beta-agent"
  end

  test "search orders by domain score when domain filter provided" do
    @agent1.update!(target_domains: %w[coding], coding_score: 75, coding_evals_count: 5)
    @agent2.update!(target_domains: %w[coding], coding_score: 90, coding_evals_count: 5)
    @agent3.update!(target_domains: %w[coding], coding_score: 85, coding_evals_count: 5)

    get search_api_v1_agents_url, params: { domain: "coding" }, as: :json

    json = JSON.parse(response.body)
    slugs = json.map { |a| a["agent"] }
    # beta-agent (90) should come before gamma-agent (85) which should come before alpha-agent (75)
    assert_equal %w[beta-agent gamma-agent alpha-agent], slugs
  end
end
