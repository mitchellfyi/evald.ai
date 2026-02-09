# frozen_string_literal: true
class Agent < ApplicationRecord
  has_many :evaluations, dependent: :destroy
  has_many :eval_runs, dependent: :destroy
  has_many :agent_scores, dependent: :destroy
  has_many :agent_telemetry_stats, dependent: :destroy
  has_many :certifications, dependent: :destroy
  has_many :security_scans, dependent: :destroy
  has_many :safety_scores, dependent: :destroy
  has_many :agent_claims, dependent: :destroy
  has_many :notification_preferences, dependent: :destroy
  has_many :security_audits, dependent: :destroy
  has_many :security_certifications, dependent: :destroy
  has_many :webhook_endpoints, dependent: :destroy
  has_many :reported_interactions, class_name: "AgentInteraction", foreign_key: :reporter_agent_id, dependent: :destroy, inverse_of: :reporter_agent
  has_many :received_interactions, class_name: "AgentInteraction", foreign_key: :target_agent_id, dependent: :destroy, inverse_of: :target_agent
  belongs_to :claimed_by_user, class_name: "User", optional: true

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }

  before_validation :generate_slug, on: :create

  scope :published, -> { where(published: true) }
  scope :featured, -> { where(featured: true) }
  scope :by_category, ->(cat) { where(category: cat) }
  scope :high_score, ->(min = 80) { where("score >= ?", min) }
  scope :recently_verified, -> { where("last_verified_at > ?", 30.days.ago) }

  CATEGORIES = %w[ coding research workflow assistant general ].freeze
  CLAIM_STATUSES = %w[ unclaimed claimed verified ].freeze
  DECAY_RATES = %w[ standard slow fast ].freeze

  # Tier 0 signal weights
  TIER0_WEIGHTS = {
    repo_health: 0.20,
    bus_factor: 0.10,
    dependency_risk: 0.15,
    documentation: 0.20,
    community: 0.15,
    license: 0.10,
    maintenance: 0.10
  }.freeze

  # Tier 1 eval weights
  TIER1_WEIGHTS = {
    completion_rate: 0.25,
    accuracy: 0.30,
    cost_efficiency: 0.15,
    scope_discipline: 0.15,
    safety: 0.15
  }.freeze

  def to_param
    slug
  end

  def compute_score!
    tier0 = compute_tier0_score
    tier1 = compute_tier1_score

    # Weighted combination: Tier0 = 40%, Tier1 = 60%
    if tier1.present?
      self.score = (tier0 * 0.4) + (tier1 * 0.6)
    else
      self.score = tier0
    end

    self.score_at_eval = score
    self.last_verified_at = Time.current
    save!
  end

  def compute_tier0_score
    total = 0
    TIER0_WEIGHTS.each do |signal, weight|
      value = send("tier0_#{signal}")
      total += (value || 0) * weight
    end
    total
  end

  def compute_tier1_score
    return nil unless tier1_completion_rate.present?

    total = 0
    TIER1_WEIGHTS.each do |metric, weight|
      value = send("tier1_#{metric}")
      total += ((value || 0) * 100) * weight
    end
    total
  end

  def decayed_score
    return score unless last_verified_at && score_at_eval

    days_since_eval = (Time.current - last_verified_at) / 1.day
    decay_factor = case decay_rate
    when "slow" then 0.001
    when "fast" then 0.005
    else 0.002 # standard
    end

    [score_at_eval - (days_since_eval * decay_factor * score_at_eval), 0].max.round(2)
  end

  def tier0_summary
    {
      repo_health: tier0_repo_health&.to_f,
      bus_factor: tier0_bus_factor&.to_f,
      dependency_risk: tier0_dependency_risk&.to_f,
      documentation: tier0_documentation&.to_f,
      community: tier0_community&.to_f,
      license: tier0_license&.to_f,
      maintenance: tier0_maintenance&.to_f
    }.compact
  end

  def tier1_summary
    return {} unless tier1_completion_rate.present?

    {
      completion_rate: tier1_completion_rate&.to_f,
      accuracy: tier1_accuracy&.to_f,
      cost_efficiency: tier1_cost_efficiency&.to_f,
      scope_discipline: tier1_scope_discipline&.to_f,
      safety: tier1_safety&.to_f
    }.compact
  end

  def badge_color
    return "gray" unless score

    case score.to_f
    when 90..100 then "brightgreen"
    when 80..89 then "green"
    when 70..79 then "yellowgreen"
    when 60..69 then "yellow"
    when 50..59 then "orange"
    else "red"
    end
  end

  # Alias for decayed_score - used by BadgeGenerator
  def overall_score
    decayed_score
  end

  # Compute tier based on score
  def tier
    score_value = decayed_score || 0
    case score_value.to_f
    when 90..100 then "platinum"
    when 80...90 then "gold"
    when 70...80 then "silver"
    when 60...70 then "bronze"
    else "unrated"
    end
  end

  # Safety level based on safety score
  def safety_level
    safety = current_safety_score&.score || tier1_safety
    return "unknown" unless safety

    case safety.to_f * 100
    when 80..100 then "safe"
    when 60...80 then "caution"
    when 40...60 then "warning"
    else "danger"
    end
  end

  # Check if agent has valid certification
  def certified?
    security_certifications.active.any?
  end

  def claimed?
    claim_status != "unclaimed"
  end

  def verified?
    claim_status == "verified"
  end

  def owner
    agent_claims.active.first&.user
  end

  def owned_by?(user)
    agent_claims.active.exists?(user: user)
  end

  def current_tier0_score
    agent_scores.tier0.current.latest.first
  end

  def current_safety_score
    safety_scores.latest.first
  end

  def latest_audit
    security_audits.order(audit_date: :desc).first
  end

  def active_certifications
    security_certifications.active
  end

  def certification_level(type)
    security_certifications.active.by_type(type).order(:level).last&.level
  end

  CONFIDENCE_LEVELS = %w[ insufficient low medium high ].freeze

  # Compute confidence level based on data availability and recency
  def confidence_level
    @confidence_level ||= confidence_factors[:level]
  end

  # Detailed breakdown of confidence calculation
  def confidence_factors
    @confidence_factors ||= compute_confidence_factors
  end

  private

  def compute_confidence_factors
    has_tier0 = tier0_summary.values.any?(&:present?)
    has_tier1 = tier1_summary.values.any?(&:present?)
    tier1_complete = has_tier1 && tier1_summary.size == TIER1_WEIGHTS.size

    completed_runs = eval_runs.completed
    tier1_run_count = completed_runs.count

    recent_cutoff = 30.days.ago
    recent_eval = last_verified_at.present? && last_verified_at > recent_cutoff

    run_scores = completed_runs.where.not(metrics: nil)
      .pluck(:metrics)
      .filter_map { |m| m["score"]&.to_f }
    low_variance = if run_scores.size >= 2
                     mean = run_scores.sum / run_scores.size
                     variance = run_scores.sum { |s| (s - mean)**2 } / run_scores.size
                     variance < 100 # standard deviation < 10 points
    else
      false
    end

    # High requires: complete tiers, multiple runs, recent data, and consistent scores
    level = if has_tier0 && tier1_complete && tier1_run_count >= 2 && recent_eval && low_variance
              "high"
            elsif has_tier0 && (has_tier1 || evaluations.completed.by_tier("tier0").where("created_at > ?", 60.days.ago).any?)
              "medium"
            elsif has_tier0
              "low"
            else
              "insufficient"
            end

    {
      level: level,
      has_tier0: has_tier0,
      has_tier1: has_tier1,
      tier1_run_count: tier1_run_count,
      recent_eval: recent_eval,
      low_variance: low_variance
    }
  end

  def generate_slug
    self.slug ||= name&.parameterize
  end
end
