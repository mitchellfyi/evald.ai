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
          provider: agent.provider,
          score: agent.score,
          tier: agent.tier,
          categories: agent.categories,
          tier_scores: tier_breakdown(agent),
          strengths: agent.categories&.first(3) || [],
          last_evaluated: agent.evaluated_at&.iso8601
        }
      end

      def tier_breakdown(agent)
        {
          tier0: agent.tier0_score,
          tier1: agent.tier1_score,
          tier2: agent.tier2_score,
          tier3: agent.tier3_score,
          tier4: agent.tier4_score
        }
      end

      def comparison_summary(agents)
        return {} if agents.empty?

        best = agents.max_by(&:score)
        {
          highest_score: best&.slug,
          average_score: (agents.sum(&:score).to_f / agents.size).round(1),
          count: agents.size
        }
      end
    end
  end
end
