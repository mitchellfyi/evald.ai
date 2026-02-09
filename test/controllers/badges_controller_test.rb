# frozen_string_literal: true
require "test_helper"

class BadgesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @agent = create(:agent, :published, :with_score, slug: "badge-agent", name: "Badge Agent")
  end

  test "show returns svg for valid agent by slug" do
    get badge_agent_path(@agent)

    assert_response :success
    assert_equal "image/svg+xml", response.media_type
  end

  test "show returns 404 svg for unknown agent" do
    get agent_badge_path(agent_name: "nonexistent-agent")

    assert_response :not_found
    assert_equal "image/svg+xml", response.media_type
  end

  test "show accepts flat style" do
    get badge_agent_path(@agent, style: "flat")
    assert_response :success
  end

  test "show accepts score type" do
    get badge_agent_path(@agent, type: "score")
    assert_response :success
  end

  test "show accepts tier type" do
    get badge_agent_path(@agent, type: "tier")
    assert_response :success
  end

  test "show sets cache headers" do
    get badge_agent_path(@agent)

    assert_includes response.headers["Cache-Control"], "public"
    assert_includes response.headers["Cache-Control"], "max-age=3600"
  end

  test "show accepts flat-square style" do
    get badge_agent_path(@agent, style: "flat-square")
    assert_response :success
  end

  test "show accepts custom label" do
    get badge_agent_path(@agent, label: "trust score")
    assert_response :success
    assert_includes response.body, "trust score"
  end

  test "show accepts tier parameter" do
    get badge_agent_path(@agent, tier: "0")
    assert_response :success
  end
end
