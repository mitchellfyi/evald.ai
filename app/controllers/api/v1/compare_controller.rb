# frozen_string_literal: true

module Api
  module V1
    class CompareController < BaseController
      def index
        slugs = params[:agents].to_s.split(",").map(&:strip).first(5)

        if slugs.empty?
          render json: { error: "agents parameter required" }, status: :bad_request
          return
        end

        if slugs.size < 2
          render json: { error: "at least 2 agents required for comparison" }, status: :bad_request
          return
        end

        agents = Agent.published.where(slug: slugs).order(:name)
        task_domain = params[:task].presence

        render json: {
          comparison: build_comparison(agents, task_domain)
        }
      end

      private

      def build_comparison(agents, task_domain)
        agent_data = agents.map { |a| comparison_data(a, task_domain) }
        best = find_best_agent(agent_data)

        {
          task_domain: task_domain || "overall",
          agents: agent_data,
          recommendation: best&.dig(:slug),
          recommendation_reason: build_recommendation_reason(best, agent_data, task_domain)
        }
      end

      def comparison_data(agent, task_domain)
        tier0 = tier0_breakdown(agent)
        tier1 = tier1_breakdown(agent)

        # If task_domain specified, adjust score weighting
        score = if task_domain.present?
                  domain_adjusted_score(agent, task_domain)
                else
                  agent.decayed_score.to_f
                end

        strengths, weaknesses = analyze_dimensions(tier0, tier1)

        {
          slug: agent.slug,
          name: agent.name,
          category: agent.category,
          score: score.round(1),
          confidence: agent.confidence_level,
          tier0: tier0,
          tier1: tier1,
          strengths: strengths,
          weaknesses: weaknesses,
          tier: agent.tier,
          last_evaluated: agent.last_verified_at&.iso8601
        }
      end

      def tier0_breakdown(agent)
        summary = agent.tier0_summary
        return {} if summary.empty?

        {
          repo_health: format_score(summary[:repo_health]),
          bus_factor: format_score(summary[:bus_factor]),
          dependency_risk: format_score(summary[:dependency_risk]),
          documentation: format_score(summary[:documentation]),
          community: format_score(summary[:community]),
          license: format_score(summary[:license]),
          maintenance: format_score(summary[:maintenance])
        }.compact
      end

      def tier1_breakdown(agent)
        summary = agent.tier1_summary
        return {} if summary.empty?

        {
          completion_rate: format_percentage(summary[:completion_rate]),
          accuracy: format_percentage(summary[:accuracy]),
          cost_efficiency: format_percentage(summary[:cost_efficiency]),
          scope_discipline: format_percentage(summary[:scope_discipline]),
          safety: format_percentage(summary[:safety])
        }.compact
      end

      def format_score(value)
        return nil unless value
        value.round(1)
      end

      def format_percentage(value)
        return nil unless value
        (value * 100).round(1)
      end

      def domain_adjusted_score(agent, task_domain)
        # For now, return decayed score. Domain-specific scoring will be
        # implemented as part of issue #88 (Domain-Specific Scoring)
        agent.decayed_score.to_f
      end

      def analyze_dimensions(tier0, tier1)
        strengths = []
        weaknesses = []

        # Analyze Tier 0 signals
        tier0_thresholds = { high: 80, low: 50 }
        tier0_labels = {
          repo_health: "healthy repository",
          bus_factor: "strong contributor diversity",
          dependency_risk: "secure dependencies",
          documentation: "excellent documentation",
          community: "active community",
          license: "clear licensing",
          maintenance: "active maintenance"
        }
        tier0_weak_labels = {
          repo_health: "repository health issues",
          bus_factor: "bus factor risk",
          dependency_risk: "dependency concerns",
          documentation: "documentation gaps",
          community: "limited community",
          license: "unclear licensing",
          maintenance: "maintenance concerns"
        }

        tier0.each do |signal, value|
          next unless value
          if value >= tier0_thresholds[:high]
            strengths << tier0_labels[signal]
          elsif value < tier0_thresholds[:low]
            weaknesses << tier0_weak_labels[signal]
          end
        end

        # Analyze Tier 1 metrics
        tier1_thresholds = { high: 80, low: 60 }
        tier1_labels = {
          completion_rate: "high task completion",
          accuracy: "high accuracy",
          cost_efficiency: "cost efficient",
          scope_discipline: "good scope control",
          safety: "safe behavior"
        }
        tier1_weak_labels = {
          completion_rate: "completion rate concerns",
          accuracy: "accuracy issues",
          cost_efficiency: "high token costs",
          scope_discipline: "scope creep tendency",
          safety: "safety concerns"
        }

        tier1.each do |metric, value|
          next unless value
          if value >= tier1_thresholds[:high]
            strengths << tier1_labels[metric]
          elsif value < tier1_thresholds[:low]
            weaknesses << tier1_weak_labels[metric]
          end
        end

        [strengths.first(4), weaknesses.first(3)]
      end

      def find_best_agent(agent_data)
        return nil if agent_data.empty?

        # Prefer high confidence agents, then highest score
        # Fall back to any agent if all have insufficient confidence
        preferred = agent_data.select { |a| a[:confidence] != "insufficient" }
        candidates = preferred.any? ? preferred : agent_data

        candidates.max_by { |a| [confidence_rank(a[:confidence]), a[:score]] }
      end

      def confidence_rank(level)
        { "high" => 3, "medium" => 2, "low" => 1, "insufficient" => 0 }[level] || 0
      end

      def build_recommendation_reason(best, agent_data, task_domain)
        return nil unless best

        domain_text = task_domain ? " for #{task_domain} tasks" : ""
        confidence_text = best[:confidence] == "high" ? " with high confidence rating" : ""

        scores = agent_data.map { |a| a[:score] }
        if scores.size > 1 && best[:score] > scores.reject { |s| s == best[:score] }.max
          "Highest Evald Score (#{best[:score]})#{confidence_text}#{domain_text}"
        else
          "Top performer#{confidence_text}#{domain_text}"
        end
      end
    end
  end
end
# CI trigger
