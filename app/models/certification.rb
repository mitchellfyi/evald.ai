# frozen_string_literal: true

class Certification < ApplicationRecord
  belongs_to :agent

  enum :tier, { bronze: 0, silver: 1, gold: 2 }
  enum :status, { pending: 0, in_review: 1, approved: 2, rejected: 3, expired: 4 }

  validates :tier, presence: true
  validates :status, presence: true
  validates :applied_at, presence: true

  before_validation :set_applied_at, on: :create

  scope :active, -> { approved.where("expires_at > ?", Time.current) }
  scope :by_tier, ->(tier) { where(tier: tier) }

  # Check if this certification is currently valid
  def valid_certification?
    approved? && expires_at.present? && expires_at > Time.current
  end

  # Duration in days for each tier
  TIER_DURATION = {
    bronze: 90,
    silver: 180,
    gold: 365
  }.freeze

  def set_expiry!
    return unless approved?

    duration = TIER_DURATION[tier.to_sym] || 90
    self.expires_at = Time.current + duration.days
    save!
  end

  private

  def set_applied_at
    self.applied_at ||= Time.current
  end
end
