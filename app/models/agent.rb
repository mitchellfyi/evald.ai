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
  has_many :agent_tags, dependent: :destroy
  has_many :tags, through: :agent_tags
  belongs_to :claimed_by_user, class_name: "User", optional: true

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }

  before_validation :generate_slug, on: :create

  scope :published, -> { where(published: true) }
  scope :featured, -> { where(featured: true) }
  scope :by_category, ->(cat) { where(category: cat) }
  scope :high_score, ->(min = 80) { where("score >= ?", min) }
  scope :recently_verified, -> { where("last_verified_at > ?", 30.days.ago) }
  scope :by_domain, ->(domain) { where("? = ANY(target_domains)", domain) }
  scope :by_primary_domain, ->(domain) { where(primary_domain: domain) }
  scope :by_tag, ->(tag_slug) { joins(:tags).where(tags: { slug: tag_slug }) }

  CATEGORIES = %w[ coding research workflow assistant general ].freeze
  CLAIM_STATUSES = %w[ unclaimed claimed verified ].freeze
  DECAY_RATES = %w[ standard slow fast ].freeze
  DOMAINS = %w[ coding research workflow ].freeze # Evaluatable domains
  # Safe mapping of domains to column names for SQL ordering
  DOMAIN_SCORE_COLUMNS = DOMAINS.index_with { |d| "#{d}_score" }.freeze

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
    # First, compute domain-specific scores from eval runs
    compute_domain_scores!

    tier0 = compute_tier0_score
    tier1 = compute_tier1_score

    # Weighted combination: Tier0 = 40%, Tier1 = 60%
    # If domain scores available, use domain-weighted score for Tier1 portion
    domain_score = domain_weighted_score

    if domain_score.present?
      # Domain-weighted score takes precedence as it's more granular
      self.score = (tier0 * 0.4) + (domain_score * 0.6)
    elsif tier1.present?
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

  # Domain-specific scoring methods
  def domain_scores
    DOMAINS.each_with_object({}) do |domain, result|
      score = send("#{domain}_score")
      evals_count = send("#{domain}_evals_count") || 0
      next unless score.present? || evals_count > 0

      result[domain] = {
        score: score&.to_f,
        confidence: domain_confidence(domain),
        evals_run: evals_count
      }
    end
  end

  def domain_confidence(domain)
    evals_count = send("#{domain}_evals_count") || 0
    case evals_count
    when 0 then "insufficient"
    when 1..2 then "low"
    when 3..5 then "medium"
    else "high"
    end
  end

  def effective_domains
    # Return agent's target domains, or infer from eval history
    return target_domains if target_domains.present?

    DOMAINS.select do |domain|
      (send("#{domain}_evals_count") || 0) > 0
    end
  end

  def compute_domain_scores!
    DOMAINS.each do |domain|
      runs = eval_runs.completed.joins(:eval_task).where(eval_tasks: { category: domain })
      next if runs.empty?

      scores = runs.filter_map { |run| run.metrics&.dig("score")&.to_f }
      next if scores.empty?

      avg_score = scores.sum / scores.size
      send("#{domain}_score=", avg_score.round(2))
      send("#{domain}_evals_count=", runs.count)
    end

    # Auto-detect primary domain if not set
    self.primary_domain ||= detect_primary_domain
    save!
  end

  def detect_primary_domain
    # Find domain with highest eval count, or highest score if tied
    best_domain = nil
    best_count = 0
    best_score = 0

    DOMAINS.each do |domain|
      count = send("#{domain}_evals_count") || 0
      score = send("#{domain}_score") || 0

      if count > best_count || (count == best_count && score > best_score)
        best_domain = domain
        best_count = count
        best_score = score
      end
    end

    best_domain
  end

  def domain_weighted_score
    # Composite score weighted by agent's relevant domains only
    domains = effective_domains
    return nil if domains.empty?

    total_score = 0
    total_weight = 0

    domains.each do |domain|
      domain_score = send("#{domain}_score")
      next unless domain_score.present?

      # Weight by eval count (more evals = higher confidence = higher weight)
      evals_count = send("#{domain}_evals_count") || 1
      weight = [evals_count, 10].min # Cap weight at 10
      total_score += domain_score * weight
      total_weight += weight
    end

    return nil if total_weight.zero?

    (total_score / total_weight).round(2)
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
