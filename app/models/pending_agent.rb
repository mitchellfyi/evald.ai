# frozen_string_literal: true

class PendingAgent < ApplicationRecord
  STATUSES = %w[pending approved rejected].freeze

  belongs_to :reviewed_by, class_name: "User", optional: true

  validates :name, presence: true
  validates :github_url, presence: true, uniqueness: true,
    format: { with: %r{\Ahttps://github\.com/[^/]+/[^/]+\z}, message: "must be a valid GitHub repository URL" }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :confidence_score, numericality: { in: 0..100, allow_nil: true }

  scope :pending, -> { where(status: "pending") }
  scope :approved, -> { where(status: "approved") }
  scope :rejected, -> { where(status: "rejected") }
  scope :high_confidence, -> { where("confidence_score >= ?", 80) }
  scope :needs_review, -> { where(confidence_score: 50..79) }
  scope :recent, -> { order(discovered_at: :desc) }

  def approve!(reviewer)
    update!(
      status: "approved",
      reviewed_by: reviewer,
      reviewed_at: Time.current
    )
  end

  def reject!(reviewer, reason: nil)
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
end
