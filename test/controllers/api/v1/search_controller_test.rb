# frozen_string_literal: true
require "test_helper"

class Api::V1::SearchControllerTest < ActionDispatch::IntegrationTest
  setup do
    @agent1 = create(:agent, :published, :with_score, name: "Alpha Agent", slug: "alpha-agent", category: "coding")
    @agent2 = create(:agent, :published, :with_score, name: "Beta Agent", slug: "beta-agent", category: "research", score: 85.0, score_at_eval: 85.0)
    @agent3 = create(:agent, :published, :with_score, name: "Gamma Agent", slug: "gamma-agent", category: "coding", score: 60.0, score_at_eval: 60.0)
    @unpublished = create(:agent, name: "Unpublished Agent", slug: "unpublished-agent")
  end

  test "index returns search results with correct structure" do
    get api_v1_search_index_url, params: { q: "Alpha" }, as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert json.key?("results")
    assert json.key?("meta")
    assert_equal 1, json["results"].size

    result = json["results"].first
    assert_equal "alpha-agent", result["slug"]
    assert_equal "Alpha Agent", result["name"]
    assert_equal "coding", result["category"]
    assert result.key?("score")
    assert result.key?("tier")
  end

  test "index filters by capability" do
    get api_v1_search_index_url, params: { capability: "research" }, as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal 1, json["results"].size
    assert_equal "beta-agent", json["results"].first["slug"]
  end

  test "index filters by minimum score" do
    get api_v1_search_index_url, params: { min_score: 80 }, as: :json

    assert_response :success
    json = JSON.parse(response.body)

    json["results"].each do |result|
      assert result["score"] >= 80
    end
  end

  test "index searches by query across name, description, and category" do
    get api_v1_search_index_url, params: { q: "coding" }, as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert json["results"].size >= 2
  end

  test "index returns empty results for no match" do
    get api_v1_search_index_url, params: { q: "nonexistent" }, as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal 0, json["results"].size
  end

  test "index returns all published agents without filters" do
    get api_v1_search_index_url, as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal 3, json["results"].size
  end

  test "score values are never nil" do
    agent = create(:agent, :published, name: "Nil Score", slug: "nil-score", score: nil)

    get api_v1_search_index_url, params: { q: "Nil Score" }, as: :json

    assert_response :success
    json = JSON.parse(response.body)

    result = json["results"].find { |r| r["slug"] == "nil-score" }
    assert_not_nil result
    assert_equal 0.0, result["score"]
  end
end
