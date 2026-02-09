class Evaluation < ApplicationRecord
  belongs_to :agent

  validates :tier, presence: true, inclusion: { in: %w[tier0 tier1 tier2] }
  validates :status, inclusion: { in: %w[pending running completed failed] }

  scope :completed, -> { where(status: 'completed') }
  scope :by_tier, ->(tier) { where(tier: tier) }
  scope :recent, -> { order(created_at: :desc) }

  def duration
    return nil unless started_at && completed_at
    completed_at - started_at
  end

  def mark_running!
    update!(status: 'running', started_at: Time.current)
  end

  def mark_completed!(new_scores)
    update!(
      status: 'completed',
      scores: new_scores,
      score: compute_overall_score(new_scores),
      completed_at: Time.current
    )
  end

  def mark_failed!(error_message = nil)
    update!(
      status: 'failed',
      notes: error_message,
      completed_at: Time.current
    )
  end

  private

  def compute_overall_score(scores_hash)
    return nil if scores_hash.blank?
    
    values = scores_hash.values.map(&:to_f)
    return nil if values.empty?
    
    (values.sum / values.size).round(2)
  end
end
