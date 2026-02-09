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

        agents = Agent.published.where(slug: slugs).order(:name)

        render json: {
          agents: agents.map { |a| comparison_data(a) },
          summary: comparison_summary(agents)
        }
      end

      private

      def comparison_data(agent)
        {
          slug: agent.slug,
          name: agent.name,
          category: agent.category,
          score: agent.decayed_score.to_f,
          tier: agent.tier,
          tier_scores: tier_breakdown(agent),
          strengths: [agent.category].compact.first(3),
          last_evaluated: agent.last_verified_at&.iso8601
        }
      end

      def tier_breakdown(agent)
        {
          tier0: agent.compute_tier0_score,
          tier1: agent.compute_tier1_score
        }
      end

      def comparison_summary(agents)
        return {} if agents.empty?

        best = agents.max_by { |a| a.decayed_score.to_f }
        {
          highest_score: best&.slug,
          average_score: (agents.sum { |a| a.decayed_score.to_f } / agents.size).round(1),
          count: agents.size
        }
      end
    end
  end
end
