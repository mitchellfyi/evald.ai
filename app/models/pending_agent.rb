# frozen_string_literal: true

class PendingAgent < ApplicationRecord
  STATUSES = %w[pending approved rejected].freeze
  AI_CLASSIFICATIONS = %w[agent sdk library tool framework unknown].freeze

  belongs_to :reviewed_by, class_name: "User", optional: true

  validates :name, presence: true
  validates :github_url, presence: true, uniqueness: true,
    format: { with: %r{\Ahttps://github\.com/[^/]+/[^/]+\z}, message: "must be a valid GitHub repository URL" }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :confidence_score, numericality: { in: 0..100, allow_nil: true }
  validates :ai_classification, inclusion: { in: AI_CLASSIFICATIONS }, allow_nil: true
  validates :ai_confidence, numericality: { in: 0.0..1.0 }, allow_nil: true

  scope :pending, -> { where(status: "pending") }
  scope :approved, -> { where(status: "approved") }
  scope :rejected, -> { where(status: "rejected") }
  scope :high_confidence, -> { where("confidence_score >= ?", 80) }
  scope :needs_review, -> { where(confidence_score: 50..79) }
  scope :recent, -> { order(discovered_at: :desc) }

  # AI review scopes
  scope :ai_reviewed, -> { where.not(ai_reviewed_at: nil) }
  scope :ai_pending_review, -> { where(ai_reviewed_at: nil) }
  scope :classified_as_agent, -> { where(is_agent: true) }
  scope :classified_as_non_agent, -> { where(is_agent: false) }
  scope :high_ai_confidence, -> { where("ai_confidence >= ?", 0.8) }
  scope :low_ai_confidence, -> { where("ai_confidence < ?", 0.5) }
  scope :needs_manual_review, -> { ai_reviewed.where("ai_confidence >= ? AND ai_confidence < ?", 0.5, 0.8) }

  def approve!(reviewer = nil)
    update!(
      status: "approved",
      reviewed_by: reviewer,
      reviewed_at: Time.current
    )
  end

  def reject!(reviewer = nil, reason: nil)
    update!(
      status: "rejected",
      reviewed_by: reviewer,
      reviewed_at: Time.current,
      rejection_reason: reason
    )
  end

  def pending?
    status == "pending"
  end

  def ai_reviewed?
    ai_reviewed_at.present?
  end

  def needs_ai_review?
    ai_reviewed_at.nil?
  end

  # Check if this should be auto-approved based on AI classification
  def auto_approvable?
    is_agent == true && ai_confidence.to_f >= 0.8
  end

  # Check if this should be auto-rejected based on AI classification
  def auto_rejectable?
    is_agent == false && ai_confidence.to_f >= 0.8
  end

  # Queue for AI review
  def queue_ai_review!
    AiAgentReviewJob.perform_later(id) unless ai_reviewed?
  end
end
