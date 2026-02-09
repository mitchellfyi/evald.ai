# frozen_string_literal: true

require "test_helper"

class AiAgentReviewJobTest < ActiveSupport::TestCase
  setup do
    @pending_agent = PendingAgent.create!(
      name: "test-agent",
      github_url: "https://github.com/test/test-agent",
      status: "pending",
      description: "A test agent",
      owner: "test",
      stars: 100,
      language: "Python",
      discovered_at: Time.current
    )
  end

  test "performs review on pending agent" do
    mock_reviewer = mock("reviewer")
    mock_reviewer.expects(:review).returns({
      "is_agent" => true,
      "classification" => "agent",
      "confidence" => 0.85,
      "categories" => ["coding"],
      "description" => "A coding agent",
      "capabilities" => ["code_gen"],
      "reasoning" => "Clear agent behavior"
    })
    AiAgentReviewer.expects(:new).returns(mock_reviewer)

    AiAgentReviewJob.perform_now(@pending_agent.id)

    @pending_agent.reload
    assert @pending_agent.ai_reviewed?
  end

  test "skips already reviewed agents" do
    @pending_agent.update!(ai_reviewed_at: Time.current)

    AiAgentReviewer.expects(:new).never

    AiAgentReviewJob.perform_now(@pending_agent.id)
  end

  test "auto-approves high confidence agents" do
    @pending_agent.update!(
      ai_reviewed_at: Time.current,
      ai_classification: "agent",
      ai_confidence: 0.9,
      is_agent: true,
      ai_description: "A great agent",
      ai_categories: ["coding"],
      ai_capabilities: ["code_gen"]
    )

    mock_reviewer = mock("reviewer")
    mock_reviewer.expects(:review).returns({
      "is_agent" => true,
      "classification" => "agent",
      "confidence" => 0.9,
      "categories" => ["coding"],
      "description" => "A great agent",
      "capabilities" => ["code_gen"],
      "reasoning" => "Clear agent"
    })
    AiAgentReviewer.expects(:new).returns(mock_reviewer)

    # Reset reviewed_at to allow job to proceed
    @pending_agent.update!(ai_reviewed_at: nil)

    assert_difference "Agent.count", 1 do
      AiAgentReviewJob.perform_now(@pending_agent.id)
    end

    @pending_agent.reload
    assert_equal "approved", @pending_agent.status
  end

  test "auto-rejects high confidence non-agents" do
    mock_reviewer = mock("reviewer")
    mock_reviewer.expects(:review).returns({
      "is_agent" => false,
      "classification" => "sdk",
      "confidence" => 0.95,
      "categories" => [],
      "description" => "An SDK",
      "capabilities" => [],
      "reasoning" => "This is a SDK, not an agent"
    })
    AiAgentReviewer.expects(:new).returns(mock_reviewer)

    AiAgentReviewJob.perform_now(@pending_agent.id)

    @pending_agent.reload
    assert_equal "rejected", @pending_agent.status
    assert_match(/SDK/, @pending_agent.rejection_reason)
  end

  test "leaves low confidence agents pending for manual review" do
    mock_reviewer = mock("reviewer")
    mock_reviewer.expects(:review).returns({
      "is_agent" => true,
      "classification" => "agent",
      "confidence" => 0.6,
      "categories" => ["coding"],
      "description" => "Maybe an agent",
      "capabilities" => [],
      "reasoning" => "Uncertain classification"
    })
    AiAgentReviewer.expects(:new).returns(mock_reviewer)

    AiAgentReviewJob.perform_now(@pending_agent.id)

    @pending_agent.reload
    assert_equal "pending", @pending_agent.status
    assert @pending_agent.ai_reviewed?
  end

  test "handles record not found gracefully" do
    assert_nothing_raised do
      AiAgentReviewJob.perform_now(999999)
    end
  end

  test "does not create duplicate agents" do
    # Create an existing agent with the same repo_url
    Agent.create!(
      name: "existing-agent",
      repo_url: @pending_agent.github_url,
      slug: "existing-agent"
    )

    mock_reviewer = mock("reviewer")
    mock_reviewer.expects(:review).returns({
      "is_agent" => true,
      "classification" => "agent",
      "confidence" => 0.9,
      "categories" => ["coding"],
      "description" => "A great agent",
      "capabilities" => ["code_gen"],
      "reasoning" => "Clear agent"
    })
    AiAgentReviewer.expects(:new).returns(mock_reviewer)

    assert_no_difference "Agent.count" do
      AiAgentReviewJob.perform_now(@pending_agent.id)
    end
  end
end
