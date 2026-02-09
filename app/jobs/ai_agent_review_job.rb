# frozen_string_literal: true

# Background job to run AI classification on pending agents
# Classifies repositories as genuine agents vs SDKs/libraries/tools
class AiAgentReviewJob < ApplicationJob
  queue_as :ai_review

  # Retry on transient failures with exponential backoff
  retry_on Faraday::Error, wait: :polynomially_longer, attempts: 3
  retry_on OpenAI::Error, wait: :polynomially_longer, attempts: 3

  # Don't retry on record not found
  discard_on ActiveRecord::RecordNotFound

  def perform(pending_agent_id)
    pending = PendingAgent.find(pending_agent_id)

    # Skip if already reviewed
    return if pending.ai_reviewed_at.present?

    Rails.logger.info("AiAgentReviewJob: reviewing #{pending.name} (#{pending.github_url})")

    reviewer = AiAgentReviewer.new(pending)
    result = reviewer.review

    # Log the result
    Rails.logger.info(
      "AiAgentReviewJob: #{pending.name} classified as #{result['classification']} " \
      "(is_agent: #{result['is_agent']}, confidence: #{result['confidence']})"
    )

    # Handle the result based on confidence and classification
    handle_result(pending.reload, result)
  end

  private

  def handle_result(pending, result)
    return if result["skipped"]

    confidence = result["confidence"].to_f
    is_agent = result["is_agent"]

    if is_agent && confidence >= AiAgentReviewer::AUTO_APPROVE_THRESHOLD
      # Auto-approve high-confidence agents
      auto_approve(pending)
    elsif !is_agent && confidence >= AiAgentReviewer::AUTO_APPROVE_THRESHOLD
      # Auto-reject high-confidence non-agents
      auto_reject(pending, result["reasoning"])
    else
      # Queue for manual review
      mark_needs_review(pending)
    end
  end

  def auto_approve(pending)
    Rails.logger.info("AiAgentReviewJob: auto-approving #{pending.name}")

    pending.update!(status: "approved")

    # Create the actual agent record
    create_agent_from_pending(pending)
  end

  def auto_reject(pending, reason)
    Rails.logger.info("AiAgentReviewJob: auto-rejecting #{pending.name} - #{reason}")

    pending.update!(
      status: "rejected",
      rejection_reason: "AI classification: #{reason}"
    )
  end

  def mark_needs_review(pending)
    Rails.logger.info("AiAgentReviewJob: #{pending.name} needs manual review")

    # Status stays "pending" but has AI review data
    # Admin can review and approve/reject manually
  end

  def create_agent_from_pending(pending)
    # Only create if agent doesn't already exist
    return if Agent.exists?(repo_url: pending.github_url)

    # Determine category from AI classification (use first category or default to "general")
    category = (pending.ai_categories&.first || "general")
    category = "general" unless Agent::CATEGORIES.include?(category)

    Agent.create!(
      name: pending.name,
      repo_url: pending.github_url,
      description: pending.ai_description.presence || pending.description,
      language: pending.language,
      stars: pending.stars || 0,
      category: category,
      metadata: {
        ai_classification: pending.ai_classification,
        ai_confidence: pending.ai_confidence,
        ai_categories: pending.ai_categories,
        ai_capabilities: pending.ai_capabilities,
        source: "ai_review"
      }
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Failed to create agent from pending #{pending.id}: #{e.message}")
  end
end
