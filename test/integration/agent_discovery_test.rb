# frozen_string_literal: true

require "test_helper"

class AgentDiscoveryTest < ActionDispatch::IntegrationTest
  setup do
    @coding_agent = create(:agent, :published, :with_score, name: "CodeBot", slug: "codebot", category: "coding", score: 85)
    @research_agent = create(:agent, :published, :with_score, name: "ResearchAI", slug: "researchai", category: "research", score: 72)
    @featured_agent = create(:agent, :published, :featured, :with_score, name: "StarAgent", slug: "staragent", category: "general", score: 95)
    @unpublished_agent = create(:agent, name: "DraftBot", slug: "draftbot", published: false)
  end

  # === Agent Index Tests ===

  test "should get agent index with published agents" do
    get agents_path
    assert_response :success
    assert_includes response.body, "CodeBot"
    assert_includes response.body, "ResearchAI"
    assert_includes response.body, "StarAgent"
  end

  test "should not show unpublished agents on index" do
    get agents_path
    assert_response :success
    assert_not_includes response.body, "DraftBot"
  end

  test "should filter agents by category" do
    get agents_path, params: { category: "coding" }
    assert_response :success
    assert_includes response.body, "CodeBot"
    assert_not_includes response.body, "ResearchAI"
  end

  test "should filter agents by minimum score" do
    get agents_path, params: { min_score: 80 }
    assert_response :success
    assert_includes response.body, "CodeBot"
    assert_includes response.body, "StarAgent"
    assert_not_includes response.body, "ResearchAI"
  end

  # === Agent Show Tests ===

  test "should show published agent profile" do
    get agent_path(@coding_agent)
    assert_response :success
    assert_includes response.body, "CodeBot"
  end

  test "should return 404 for unpublished agent" do
    get agent_path(@unpublished_agent)
    assert_response :not_found
  end

  test "should return 404 for non-existent agent" do
    get agent_path(id: "nonexistent-agent")
    assert_response :not_found
  end

  # === Agent Compare Tests ===

  test "should compare multiple agents" do
    get compare_path, params: { agents: "codebot,researchai" }
    assert_response :success
    assert_includes response.body, "CodeBot"
    assert_includes response.body, "ResearchAI"
  end

  test "should limit comparison to 5 agents" do
    # Create additional agents
    agents = 6.times.map { |i| create(:agent, :published, name: "Agent#{i}", slug: "agent-#{i}") }
    slugs = agents.map(&:slug).join(",")

    get compare_path, params: { agents: slugs }
    assert_response :success
    # Should only include first 5
    assert_includes response.body, "Agent0"
    assert_includes response.body, "Agent4"
    assert_not_includes response.body, "Agent5"
  end

  # === API Agent Endpoints ===

  test "API should return agents list" do
    get api_v1_agents_path
    assert_response :success

    json = JSON.parse(response.body)
    assert_kind_of Array, json
    assert json.any? { |a| a["agent"] == "codebot" }
  end

  test "API should filter by capability" do
    get api_v1_agents_path, params: { capability: "coding" }
    assert_response :success

    json = JSON.parse(response.body)
    assert json.all? { |a| a["category"] == "coding" }
  end

  test "API should return agent details" do
    get api_v1_agent_path(@coding_agent)
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal "codebot", json["agent"]
    assert_equal "CodeBot", json["name"]
    assert_equal "coding", json["category"]
  end

  test "API should return 404 for unknown agent" do
    get api_v1_agent_path(id: "unknown-slug")
    assert_response :not_found

    json = JSON.parse(response.body)
    assert_equal "Not found", json["error"]
  end

  test "API should return agent score" do
    get score_api_v1_agent_path(@coding_agent)
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal "codebot", json["agent"]
    assert json.key?("score")
  end

  test "API should compare agents" do
    get compare_api_v1_agents_path, params: { agents: "codebot,researchai" }
    assert_response :success

    json = JSON.parse(response.body)
    assert json.key?("agents")
    assert_equal 2, json["agents"].length
    assert json.key?("recommendation")
  end

  test "API should search agents" do
    get search_api_v1_agents_path, params: { q: "Code" }
    assert_response :success

    json = JSON.parse(response.body)
    assert json.any? { |a| a["name"] == "CodeBot" }
  end
end
