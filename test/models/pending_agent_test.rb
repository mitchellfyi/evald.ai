# frozen_string_literal: true

require "test_helper"

class PendingAgentTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "factory creates valid pending agent" do
    pending_agent = build(:pending_agent)
    assert pending_agent.valid?
  end

  test "requires name" do
    pending_agent = build(:pending_agent, name: nil)
    refute pending_agent.valid?
    assert_includes pending_agent.errors[:name], "can't be blank"
  end

  test "requires github_url" do
    pending_agent = build(:pending_agent, github_url: nil)
    refute pending_agent.valid?
    assert_includes pending_agent.errors[:github_url], "can't be blank"
  end

  test "github_url must be unique" do
    create(:pending_agent, github_url: "https://github.com/org/repo")
    duplicate = build(:pending_agent, github_url: "https://github.com/org/repo")
    refute duplicate.valid?
    assert_includes duplicate.errors[:github_url], "has already been taken"
  end

  test "github_url must be valid GitHub URL" do
    pending_agent = build(:pending_agent, github_url: "https://example.com/not-github")
    refute pending_agent.valid?
    assert_includes pending_agent.errors[:github_url], "must be a valid GitHub repository URL"
  end

  test "status must be valid" do
    pending_agent = build(:pending_agent, status: "invalid")
    refute pending_agent.valid?
    assert_includes pending_agent.errors[:status], "is not included in the list"
  end

  test "confidence_score must be between 0 and 100" do
    over = build(:pending_agent, confidence_score: 101)
    under = build(:pending_agent, confidence_score: -1)
    refute over.valid?
    refute under.valid?
  end

  test "confidence_score can be nil" do
    pending_agent = build(:pending_agent, confidence_score: nil)
    assert pending_agent.valid?
  end

  test "pending scope returns only pending agents" do
    pending = create(:pending_agent, status: "pending")
    approved = create(:pending_agent, :approved)

    result = PendingAgent.pending
    assert_includes result, pending
    refute_includes result, approved
  end

  test "approved scope returns only approved agents" do
    pending = create(:pending_agent, status: "pending")
    approved = create(:pending_agent, :approved)

    result = PendingAgent.approved
    assert_includes result, approved
    refute_includes result, pending
  end

  test "high_confidence scope returns agents with score >= 80" do
    high = create(:pending_agent, :high_confidence)
    low = create(:pending_agent, :low_confidence)

    result = PendingAgent.high_confidence
    assert_includes result, high
    refute_includes result, low
  end

  test "approve! updates status and reviewer" do
    pending_agent = create(:pending_agent)
    reviewer = create(:user)

    pending_agent.approve!(reviewer)
    pending_agent.reload

    assert_equal "approved", pending_agent.status
    assert_equal reviewer, pending_agent.reviewed_by
    assert_not_nil pending_agent.reviewed_at
  end

  test "reject! updates status, reviewer, and reason" do
    pending_agent = create(:pending_agent)
    reviewer = create(:user)

    pending_agent.reject!(reviewer, reason: "Not an agent")
    pending_agent.reload

    assert_equal "rejected", pending_agent.status
    assert_equal reviewer, pending_agent.reviewed_by
    assert_equal "Not an agent", pending_agent.rejection_reason
    assert_not_nil pending_agent.reviewed_at
  end

  test "pending? returns true for pending status" do
    assert build(:pending_agent, status: "pending").pending?
    refute build(:pending_agent, status: "approved").pending?
  end

  # AI review tests
  test "ai_classification must be valid if present" do
    pending_agent = build(:pending_agent, ai_classification: "invalid")
    refute pending_agent.valid?
    assert_includes pending_agent.errors[:ai_classification], "is not included in the list"
  end

  test "ai_classification can be nil" do
    pending_agent = build(:pending_agent, ai_classification: nil)
    assert pending_agent.valid?
  end

  test "ai_confidence must be between 0 and 1" do
    over = build(:pending_agent, ai_confidence: 1.5)
    under = build(:pending_agent, ai_confidence: -0.1)
    refute over.valid?
    refute under.valid?
  end

  test "ai_confidence can be nil" do
    pending_agent = build(:pending_agent, ai_confidence: nil)
    assert pending_agent.valid?
  end

  test "ai_reviewed? returns true when ai_reviewed_at is set" do
    pending_agent = build(:pending_agent, ai_reviewed_at: Time.current)
    assert pending_agent.ai_reviewed?
  end

  test "ai_reviewed? returns false when ai_reviewed_at is nil" do
    pending_agent = build(:pending_agent, ai_reviewed_at: nil)
    refute pending_agent.ai_reviewed?
  end

  test "needs_ai_review? is inverse of ai_reviewed?" do
    reviewed = build(:pending_agent, ai_reviewed_at: Time.current)
    not_reviewed = build(:pending_agent, ai_reviewed_at: nil)

    refute reviewed.needs_ai_review?
    assert not_reviewed.needs_ai_review?
  end

  test "auto_approvable? returns true for high confidence agents" do
    pending_agent = build(:pending_agent, is_agent: true, ai_confidence: 0.85)
    assert pending_agent.auto_approvable?
  end

  test "auto_approvable? returns false for low confidence agents" do
    pending_agent = build(:pending_agent, is_agent: true, ai_confidence: 0.6)
    refute pending_agent.auto_approvable?
  end

  test "auto_approvable? returns false for non-agents" do
    pending_agent = build(:pending_agent, is_agent: false, ai_confidence: 0.9)
    refute pending_agent.auto_approvable?
  end

  test "auto_rejectable? returns true for high confidence non-agents" do
    pending_agent = build(:pending_agent, is_agent: false, ai_confidence: 0.85)
    assert pending_agent.auto_rejectable?
  end

  test "auto_rejectable? returns false for low confidence" do
    pending_agent = build(:pending_agent, is_agent: false, ai_confidence: 0.6)
    refute pending_agent.auto_rejectable?
  end

  test "ai_reviewed scope returns agents with ai_reviewed_at set" do
    reviewed = create(:pending_agent, ai_reviewed_at: Time.current)
    not_reviewed = create(:pending_agent, ai_reviewed_at: nil)

    result = PendingAgent.ai_reviewed
    assert_includes result, reviewed
    refute_includes result, not_reviewed
  end

  test "ai_pending_review scope returns agents without ai_reviewed_at" do
    reviewed = create(:pending_agent, ai_reviewed_at: Time.current)
    not_reviewed = create(:pending_agent, ai_reviewed_at: nil)

    result = PendingAgent.ai_pending_review
    assert_includes result, not_reviewed
    refute_includes result, reviewed
  end

  test "classified_as_agent scope returns agents where is_agent is true" do
    agent = create(:pending_agent, is_agent: true)
    non_agent = create(:pending_agent, is_agent: false)

    result = PendingAgent.classified_as_agent
    assert_includes result, agent
    refute_includes result, non_agent
  end

  test "queue_ai_review! enqueues job if not reviewed" do
    pending_agent = create(:pending_agent, ai_reviewed_at: nil)

    assert_enqueued_with(job: AiAgentReviewJob, args: [pending_agent.id]) do
      pending_agent.queue_ai_review!
    end
  end

  test "queue_ai_review! does not enqueue job if already reviewed" do
    pending_agent = create(:pending_agent, ai_reviewed_at: Time.current)

    assert_no_enqueued_jobs(only: AiAgentReviewJob) do
      pending_agent.queue_ai_review!
    end
  end
end
