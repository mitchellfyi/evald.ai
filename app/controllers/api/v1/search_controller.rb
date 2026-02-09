# frozen_string_literal: true

module Api
  module V1
    class SearchController < BaseController
      def index
        agents = Agent.published

        agents = agents.by_category(params[:capability]) if params[:capability].present?
        agents = agents.high_score(params[:min_score].to_i) if params[:min_score].present?

        if params[:q].present?
          agents = agents.where(
            "name ILIKE :q OR description ILIKE :q OR category ILIKE :q",
            q: "%#{params[:q]}%"
          )
        end

        agents = agents.order(score: :desc).limit(params[:limit] || 20)

        render json: {
          results: agents.map { |a| search_result(a) },
          meta: {
            total: agents.size,
            capability: params[:capability],
            min_score: params[:min_score]
          }
        }
      end

      private

      def search_result(agent)
        {
          slug: agent.slug,
          name: agent.name,
          category: agent.category,
          score: agent.decayed_score.to_f,
          tier: agent.tier,
          description: agent.description&.truncate(200)
        }
      end
    end
  end
end
