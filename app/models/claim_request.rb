class ClaimRequest < ApplicationRecord
  belongs_to :agent
  belongs_to :user

  enum :status, { pending: 0, verified: 1, rejected: 2 }

  validates :agent_id, presence: true
  validates :user_id, presence: true
  validates :status, presence: true
  validates :requested_at, presence: true
  validates :agent_id, uniqueness: { scope: :user_id, message: "already has a pending claim from this user" },
            if: -> { pending? }

  before_validation :set_defaults, on: :create

  scope :pending_claims, -> { where(status: :pending) }
  scope :verified_claims, -> { where(status: :verified) }

  def verify!(verification_data = {})
    update!(
      status: :verified,
      verified_at: Time.current,
      github_verification: verification_data
    )
  end

  def reject!
    update!(status: :rejected)
  end

  private

  def set_defaults
    self.status ||= :pending
    self.requested_at ||= Time.current
  end
end
