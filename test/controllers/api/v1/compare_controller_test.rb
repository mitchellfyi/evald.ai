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

    assert json.key?("comparison")
    comparison = json["comparison"]

    assert comparison.key?("task_domain")
    assert comparison.key?("agents")
    assert comparison.key?("recommendation")
    assert comparison.key?("recommendation_reason")

    assert_equal 2, comparison["agents"].size

    agent = comparison["agents"].first
    assert agent.key?("slug")
    assert agent.key?("name")
    assert agent.key?("category")
    assert agent.key?("score")
    assert agent.key?("confidence")
    assert agent.key?("tier0")
    assert agent.key?("tier1")
    assert agent.key?("strengths")
    assert agent.key?("weaknesses")
    assert agent.key?("tier")
    assert agent.key?("last_evaluated")
  end

  test "index returns error without agents parameter" do
    get api_v1_compare_index_url, as: :json

    assert_response :bad_request
    json = JSON.parse(response.body)

    assert_equal "agents parameter required", json["error"]
  end

  test "index returns error with only one agent" do
    get api_v1_compare_index_url, params: { agents: "alpha-agent" }, as: :json

    assert_response :bad_request
    json = JSON.parse(response.body)

    assert_equal "at least 2 agents required for comparison", json["error"]
  end

  test "index returns recommendation for highest scoring agent" do
    get api_v1_compare_index_url, params: { agents: "alpha-agent,beta-agent" }, as: :json

    json = JSON.parse(response.body)
    comparison = json["comparison"]

    assert_equal "beta-agent", comparison["recommendation"]
    assert comparison["recommendation_reason"].include?("Highest")
  end

  test "index limits to 5 agents" do
    6.times { |i| create(:agent, :published, :with_score, slug: "extra-#{i}") }

    agents = "alpha-agent,beta-agent,gamma-agent,extra-0,extra-1,extra-2,extra-3"
    get api_v1_compare_index_url, params: { agents: agents }, as: :json

    json = JSON.parse(response.body)
    assert json["comparison"]["agents"].size <= 5
  end

  test "index ignores unknown agents but requires at least 2 valid" do
    get api_v1_compare_index_url, params: { agents: "alpha-agent,beta-agent,nonexistent" }, as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal 2, json["comparison"]["agents"].size
  end

  test "score values are never nil" do
    agent = create(:agent, :published, name: "Nil Score", slug: "nil-score", score: nil)

    get api_v1_compare_index_url, params: { agents: "nil-score,alpha-agent" }, as: :json

    assert_response :success
    json = JSON.parse(response.body)

    nil_agent = json["comparison"]["agents"].find { |a| a["slug"] == "nil-score" }
    assert_not_nil nil_agent
    assert_equal 0.0, nil_agent["score"]
  end

  test "tier0 and tier1 contain dimension breakdowns" do
    get api_v1_compare_index_url, params: { agents: "alpha-agent,beta-agent" }, as: :json

    json = JSON.parse(response.body)
    agent = json["comparison"]["agents"].first

    # tier0 and tier1 should be hashes
    assert agent["tier0"].is_a?(Hash)
    assert agent["tier1"].is_a?(Hash)
  end

  test "supports optional task domain parameter" do
    get api_v1_compare_index_url, params: { agents: "alpha-agent,beta-agent", task: "code-review" }, as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal "code-review", json["comparison"]["task_domain"]
  end

  test "strengths and weaknesses are arrays" do
    get api_v1_compare_index_url, params: { agents: "alpha-agent,beta-agent" }, as: :json

    json = JSON.parse(response.body)
    agent = json["comparison"]["agents"].first

    assert agent["strengths"].is_a?(Array)
    assert agent["weaknesses"].is_a?(Array)
  end

  test "confidence is present and valid" do
    get api_v1_compare_index_url, params: { agents: "alpha-agent,beta-agent" }, as: :json

    json = JSON.parse(response.body)
    agent = json["comparison"]["agents"].first

    valid_confidences = %w[insufficient low medium high]
    assert valid_confidences.include?(agent["confidence"])
  end
end
