# frozen_string_literal: true
require "test_helper"

class Api::V1::CompareControllerTest < ActionDispatch::IntegrationTest
  setup do
    @agent1 = create(:agent, :published, :with_score, name: "Alpha Agent", slug: "alpha-agent", category: "coding")
    @agent2 = create(:agent, :published, :with_score, name: "Beta Agent", slug: "beta-agent", category: "research", score: 85.0, score_at_eval: 85.0)
    @agent3 = create(:agent, :published, :with_score, name: "Gamma Agent", slug: "gamma-agent", category: "coding", score: 60.0, score_at_eval: 60.0)
  end

  test "index returns comparison data with correct structure" do
    get api_v1_compare_index_url, params: { agents: "alpha-agent,beta-agent" }, as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert json.key?("agents")
    assert json.key?("summary")
    assert_equal 2, json["agents"].size

    agent = json["agents"].first
    assert agent.key?("slug")
    assert agent.key?("name")
    assert agent.key?("category")
    assert agent.key?("score")
    assert agent.key?("tier")
    assert agent.key?("tier_scores")
    assert agent.key?("last_evaluated")
  end

  test "index returns error without agents parameter" do
    get api_v1_compare_index_url, as: :json

    assert_response :bad_request
    json = JSON.parse(response.body)

    assert_equal "agents parameter required", json["error"]
  end

  test "index returns summary with highest score" do
    get api_v1_compare_index_url, params: { agents: "alpha-agent,beta-agent" }, as: :json

    json = JSON.parse(response.body)

    assert_equal "beta-agent", json["summary"]["highest_score"]
    assert json["summary"].key?("average_score")
    assert_equal 2, json["summary"]["count"]
  end

  test "index limits to 5 agents" do
    6.times { |i| create(:agent, :published, slug: "extra-#{i}") }

    agents = "alpha-agent,beta-agent,gamma-agent,extra-0,extra-1,extra-2,extra-3"
    get api_v1_compare_index_url, params: { agents: agents }, as: :json

    json = JSON.parse(response.body)
    assert json["agents"].size <= 5
  end

  test "index ignores unknown agents" do
    get api_v1_compare_index_url, params: { agents: "alpha-agent,nonexistent" }, as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal 1, json["agents"].size
  end

  test "score values are never nil" do
    agent = create(:agent, :published, name: "Nil Score", slug: "nil-score", score: nil)

    get api_v1_compare_index_url, params: { agents: "nil-score,alpha-agent" }, as: :json

    assert_response :success
    json = JSON.parse(response.body)

    nil_agent = json["agents"].find { |a| a["slug"] == "nil-score" }
    assert_not_nil nil_agent
    assert_equal 0.0, nil_agent["score"]
  end

  test "tier_scores contains tier0 and tier1" do
    get api_v1_compare_index_url, params: { agents: "alpha-agent" }, as: :json

    json = JSON.parse(response.body)
    tier_scores = json["agents"].first["tier_scores"]

    assert tier_scores.key?("tier0")
    assert tier_scores.key?("tier1")
  end
end
