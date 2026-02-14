# frozen_string_literal: true

require "test_helper"

class RouterControllerTest < ActionDispatch::IntegrationTest
  setup do
    @coding_agent = create(:agent, :published, :with_score,
      name: "Code Bot", slug: "code-bot",
      category: "coding", description: "Writes code",
      score: 85.0, score_at_eval: 85.0)
  end

  test "show renders router page" do
    get router_url

    assert_response :success
  end

  test "match with prompt returns results" do
    post router_url, params: { prompt: "Write a Python function" }

    assert_response :success
  end

  test "match with blank prompt renders without error" do
    post router_url, params: { prompt: "" }

    assert_response :success
  end
end
