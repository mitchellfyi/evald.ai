# frozen_string_literal: true

require "test_helper"

class AiAgentReviewerTest < ActiveSupport::TestCase
  setup do
    @pending_agent = PendingAgent.create!(
      name: "test-agent",
      github_url: "https://github.com/test/test-agent",
      status: "pending",
      discovered_at: Time.current
    )

    @mock_openai_client = mock("openai_client")
    @reviewer = AiAgentReviewer.new(@pending_agent, client: @mock_openai_client)
  end

  test "review returns skip result if already reviewed" do
    @pending_agent.update!(ai_reviewed_at: Time.current)

    result = @reviewer.review

    assert result["skipped"]
    assert_equal "Already reviewed", result["reasoning"]
  end

  test "review classifies repository as agent" do
    stub_github_data
    stub_openai_agent_response

    result = @reviewer.review

    assert result["is_agent"]
    assert_equal "agent", result["classification"]
    assert result["confidence"] >= 0.8
    assert_includes result["categories"], "coding"

    @pending_agent.reload
    assert @pending_agent.ai_reviewed?
    assert @pending_agent.is_agent
    assert_equal "agent", @pending_agent.ai_classification
  end

  test "review classifies repository as non-agent (sdk)" do
    stub_github_data
    stub_openai_sdk_response

    result = @reviewer.review

    refute result["is_agent"]
    assert_equal "sdk", result["classification"]
    assert result["confidence"] >= 0.8

    @pending_agent.reload
    assert @pending_agent.ai_reviewed?
    refute @pending_agent.is_agent
    assert_equal "sdk", @pending_agent.ai_classification
  end

  test "review handles API errors gracefully" do
    stub_github_data
    @mock_openai_client.expects(:chat).raises(Faraday::ConnectionFailed.new("Connection refused"))

    result = @reviewer.review

    assert result["skipped"]
    assert_match(/API error/, result["reasoning"])
  end

  test "review handles missing README" do
    GithubClient.any_instance.stubs(:fetch_readme).returns(nil)
    GithubClient.any_instance.stubs(:fetch_repository).returns({
      "name" => "test-agent",
      "description" => "An AI agent",
      "language" => "Python",
      "topics" => ["ai-agent"],
      "stargazers_count" => 500
    })
    stub_openai_agent_response

    result = @reviewer.review

    # Should still work with just repo info
    assert result["is_agent"]
  end

  test "confidence thresholds are respected" do
    assert_equal 0.8, AiAgentReviewer::AUTO_APPROVE_THRESHOLD
    assert_equal 0.3, AiAgentReviewer::AUTO_REJECT_THRESHOLD
  end

  private

  def stub_github_data
    GithubClient.any_instance.stubs(:fetch_readme).returns("# Test Agent\n\nAn autonomous AI agent that helps with coding tasks.")
    GithubClient.any_instance.stubs(:fetch_repository).returns({
      "name" => "test-agent",
      "description" => "An autonomous AI coding agent",
      "language" => "Python",
      "topics" => ["ai-agent", "autonomous-agent"],
      "stargazers_count" => 500
    })
  end

  def stub_openai_agent_response
    response = {
      "choices" => [
        {
          "message" => {
            "content" => {
              "is_agent" => true,
              "classification" => "agent",
              "confidence" => 0.92,
              "categories" => ["coding"],
              "description" => "An autonomous AI coding agent that helps with development tasks.",
              "capabilities" => ["code_generation", "bug_fixing", "refactoring"],
              "reasoning" => "Clear evidence of autonomous behavior in the README."
            }.to_json
          }
        }
      ]
    }
    @mock_openai_client.expects(:chat).returns(response)
  end

  def stub_openai_sdk_response
    response = {
      "choices" => [
        {
          "message" => {
            "content" => {
              "is_agent" => false,
              "classification" => "sdk",
              "confidence" => 0.88,
              "categories" => [],
              "description" => "A SDK for building AI agents.",
              "capabilities" => [],
              "reasoning" => "This is a library for building agents, not an agent itself."
            }.to_json
          }
        }
      ]
    }
    @mock_openai_client.expects(:chat).returns(response)
  end
end
