# frozen_string_literal: true

require "test_helper"

class BadgeGenerationTest < ActionDispatch::IntegrationTest
  setup do
    @agent = create(:agent, :published, :with_score,
      name: "TestAgent",
      slug: "testagent",
      score: 85,
      score_at_eval: 85,
      last_verified_at: 1.day.ago
    )
  end

  # === Badge Endpoint Tests ===

  test "should generate SVG badge for valid agent" do
    get agent_badge_path(agent_name: @agent.name)
    assert_response :success
    assert response.content_type.start_with?("image/svg+xml"), "Expected SVG content type, got: #{response.content_type}"

    # Verify it's valid SVG
    assert_includes response.body, "<svg"
    assert_includes response.body, "</svg>"
  end

  test "should return 404 SVG for unknown agent" do
    get agent_badge_path(agent_name: "NonExistentAgent")
    assert_response :not_found
    assert response.content_type.start_with?("image/svg+xml"), "Expected SVG content type, got: #{response.content_type}"

    # Should still be valid SVG with error message
    assert_includes response.body, "<svg"
    assert_includes response.body, "Agent Not Found"
  end

  # === Badge Style Tests ===

  test "should generate flat style badge" do
    get agent_badge_path(agent_name: @agent.name), params: { style: "flat" }
    assert_response :success
    assert_includes response.body, "<svg"
  end

  test "should generate plastic style badge" do
    get agent_badge_path(agent_name: @agent.name), params: { style: "plastic" }
    assert_response :success
    assert_includes response.body, "<svg"
  end

  test "should generate for-the-badge style badge" do
    get agent_badge_path(agent_name: @agent.name), params: { style: "for-the-badge" }
    assert_response :success
    assert_includes response.body, "<svg"
  end

  test "should default to flat style for invalid style param" do
    get agent_badge_path(agent_name: @agent.name), params: { style: "invalid" }
    assert_response :success
    assert_includes response.body, "<svg"
  end

  # === Badge Type Tests ===

  test "should generate score badge by default" do
    get agent_badge_path(agent_name: @agent.name)
    assert_response :success
    assert_includes response.body, "evald"
  end

  test "should generate tier badge" do
    get agent_badge_path(agent_name: @agent.name), params: { type: "tier" }
    assert_response :success
    assert_includes response.body, "evald tier"
  end

  test "should generate safety badge" do
    get agent_badge_path(agent_name: @agent.name), params: { type: "safety" }
    assert_response :success
    assert_includes response.body, "safety"
  end

  test "should generate certification badge" do
    get agent_badge_path(agent_name: @agent.name), params: { type: "certification" }
    assert_response :success
    assert_includes response.body, "evald"
  end

  test "should default to score type for invalid type param" do
    get agent_badge_path(agent_name: @agent.name), params: { type: "invalid" }
    assert_response :success
    assert_includes response.body, "evald"
  end

  # === Cache Headers Tests ===

  test "should set cache control headers" do
    get agent_badge_path(agent_name: @agent.name)
    assert_response :success

    assert response.headers["Cache-Control"].present?
    assert_includes response.headers["Cache-Control"], "public"
    assert_includes response.headers["Cache-Control"], "max-age=3600"
  end

  test "should set surrogate control header" do
    get agent_badge_path(agent_name: @agent.name)
    assert_response :success

    assert_equal "max-age=86400", response.headers["Surrogate-Control"]
  end

  # === Badge via Agent Member Route ===

  test "should generate badge via agent member route" do
    get badge_agent_path(@agent)
    assert_response :success
    assert response.content_type.start_with?("image/svg+xml"), "Expected SVG content type, got: #{response.content_type}"
    assert_includes response.body, "<svg"
  end

  # === Score Color Tests ===

  test "badge should reflect high score color" do
    @agent.update!(score: 95)
    get agent_badge_path(agent_name: @agent.name)
    assert_response :success
    # High scores should have green color (#4c1)
    assert_includes response.body, "#4c1"
  end

  test "badge should reflect low score color" do
    @agent.update!(score: 15, score_at_eval: 15)
    get agent_badge_path(agent_name: @agent.name)
    assert_response :success
    # Low scores should have red color (#e05d44)
    assert_includes response.body, "#e05d44"
  end

  # === Edge Cases ===

  test "should handle agent with nil score" do
    @agent.update!(score: nil)
    get agent_badge_path(agent_name: @agent.name)
    assert_response :success
    assert_includes response.body, "<svg"
  end

  test "should handle agent name with special characters" do
    special_agent = create(:agent, :published, name: "Agent<Test>&'\"", slug: "agent-test")
    get agent_badge_path(agent_name: special_agent.name)
    assert_response :success
    # Should escape XML special characters
    assert_not_includes response.body, "<Test>"
  end
end
