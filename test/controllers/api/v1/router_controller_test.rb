# frozen_string_literal: true

require "test_helper"

class Api::V1::RouterControllerTest < ActionDispatch::IntegrationTest
  setup do
    @coding_agent = create(:agent, :published, :with_score,
      name: "Code Bot", slug: "code-bot",
      category: "coding", description: "Writes code",
      score: 85.0, score_at_eval: 85.0)
    @research_agent = create(:agent, :published, :with_score,
      name: "Research Bot", slug: "research-bot",
      category: "research", description: "Does research",
      score: 80.0, score_at_eval: 80.0)
  end

  test "create returns matches with correct structure" do
    post api_v1_router_index_url, params: { prompt: "Write a Python function" }, as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert json.key?("classification")
    assert json.key?("matches")
    assert json.key?("meta")

    classification = json["classification"]
    assert classification.key?("category")
    assert classification.key?("subcategory")
    assert classification.key?("confidence")
  end

  test "create returns match data with expected fields" do
    post api_v1_router_index_url, params: { prompt: "Write a Python function" }, as: :json

    assert_response :success
    json = JSON.parse(response.body)

    next unless json["matches"].present?

    match = json["matches"].first
    assert match.key?("slug")
    assert match.key?("name")
    assert match.key?("category")
    assert match.key?("score")
    assert match.key?("reasons")
    assert match.key?("agent_score")
    assert match.key?("tier")
    assert match.key?("description")
  end

  test "create returns error without prompt" do
    post api_v1_router_index_url, params: {}, as: :json

    assert_response :bad_request
    json = JSON.parse(response.body)

    assert_equal "prompt parameter required", json["error"]
  end

  test "create returns error with blank prompt" do
    post api_v1_router_index_url, params: { prompt: "   " }, as: :json

    assert_response :bad_request
    json = JSON.parse(response.body)

    assert_equal "prompt parameter required", json["error"]
  end

  test "create classifies coding prompt correctly" do
    post api_v1_router_index_url, params: { prompt: "Debug this Python error" }, as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal "coding", json["classification"]["category"]
  end

  test "create returns meta with total and prompt_length" do
    prompt = "Write some Python code"
    post api_v1_router_index_url, params: { prompt: prompt }, as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert json["meta"]["total"].is_a?(Integer)
    assert_equal prompt.length, json["meta"]["prompt_length"]
  end

  test "create respects limit parameter" do
    post api_v1_router_index_url, params: { prompt: "Write code", limit: 1 }, as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert json["matches"].size <= 1
  end

  test "create excludes unpublished agents" do
    create(:agent, name: "Hidden", slug: "hidden", category: "coding", published: false)

    post api_v1_router_index_url, params: { prompt: "Write code" }, as: :json

    assert_response :success
    json = JSON.parse(response.body)

    slugs = json["matches"].map { |m| m["slug"] }
    assert_not_includes slugs, "hidden"
  end
end
