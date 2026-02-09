class Agent < ApplicationRecord
  has_many :evaluations, dependent: :destroy
  has_many :agent_scores, dependent: :destroy
  has_many :agent_telemetry_stats, dependent: :destroy
  has_many :certifications, dependent: :destroy
  has_many :security_scans, dependent: :destroy
  has_many :safety_scores, dependent: :destroy
  belongs_to :claimed_by_user, class_name: "User", optional: true

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }

  before_validation :generate_slug, on: :create

  scope :published, -> { where(published: true) }
  scope :featured, -> { where(featured: true) }
  scope :by_category, ->(cat) { where(category: cat) }
  scope :high_score, ->(min = 80) { where("score >= ?", min) }
  scope :recently_verified, -> { where("last_verified_at > ?", 30.days.ago) }

  CATEGORIES = %w[coding research workflow assistant general].freeze
  CLAIM_STATUSES = %w[unclaimed claimed verified].freeze
  DECAY_RATES = %w[standard slow fast].freeze

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

    [ score_at_eval - (days_since_eval * decay_factor * score_at_eval), 0 ].max.round(2)
  end

  def tier0_summary
    {
      repo_health: tier0_repo_health,
      bus_factor: tier0_bus_factor,
      dependency_risk: tier0_dependency_risk,
      documentation: tier0_documentation,
      community: tier0_community,
      license: tier0_license,
      maintenance: tier0_maintenance
    }.compact
  end

  def tier1_summary
    return {} unless tier1_completion_rate.present?

    {
      completion_rate: tier1_completion_rate,
      accuracy: tier1_accuracy,
      cost_efficiency: tier1_cost_efficiency,
      scope_discipline: tier1_scope_discipline,
      safety: tier1_safety
    }.compact
  end

  def badge_color
    return "gray" unless score

    case score
    when 90..100 then "brightgreen"
    when 80..89 then "green"
    when 70..79 then "yellowgreen"
    when 60..69 then "yellow"
    when 50..59 then "orange"
    else "red"
    end
  end

  def claimed?
    claim_status != "unclaimed"
  end

  def verified?
    claim_status == "verified"
  end

  def current_tier0_score
    agent_scores.tier0.current.latest.first
  end

  def current_safety_score
    safety_scores.latest.first
  end

  private

  def generate_slug
    self.slug ||= name&.parameterize
  end
end
