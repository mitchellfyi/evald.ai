# frozen_string_literal: true
module Tier0
  class ScoringEngine
    WEIGHTS = {
      repo_health: 0.15,
      bus_factor: 0.15,
      dependency_risk: 0.15,
      documentation: 0.15,
      community_signal: 0.15,
      license_clarity: 0.10,
      maintenance_pulse: 0.15
    }.freeze

    EXPIRY_DAYS = 30

    def initialize(agent)
      @agent = agent
    end

    def evaluate
      breakdown = {
        repo_health: RepoHealthAnalyzer.new(@agent).analyze,
        bus_factor: BusFactorAnalyzer.new(@agent).analyze,
        dependency_risk: DependencyRiskAnalyzer.new(@agent).analyze,
        documentation: DocumentationAnalyzer.new(@agent).analyze,
        community_signal: CommunitySignalAnalyzer.new(@agent).analyze,
        license_clarity: LicenseClarityAnalyzer.new(@agent).analyze,
        maintenance_pulse: MaintenancePulseAnalyzer.new(@agent).analyze
      }

      overall = calculate_weighted_score(breakdown)

      AgentScore.create!(
        agent: @agent,
        tier: 0,
        overall_score: overall,
        breakdown: breakdown,
        evaluated_at: Time.current,
        expires_at: EXPIRY_DAYS.days.from_now
      )
    end

    private

    def calculate_weighted_score(breakdown)
      WEIGHTS.sum do |key, weight|
        (breakdown.dig(key, :score) || 0) * weight
      end.round
    end
  end
end
