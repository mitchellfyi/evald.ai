# frozen_string_literal: true

module Api
  module V1
    class RouterController < BaseController
      def create
        prompt = params[:prompt].to_s.strip

        if prompt.blank?
          render json: { error: "prompt parameter required" }, status: :bad_request
          return
        end

        classification = PromptClassifier.classify(prompt)

        raw_limit = params[:limit]
        limit = Integer(raw_limit, exception: false) if raw_limit.present?
        limit = 5 if limit.nil? || limit <= 0
        limit = [limit, 50].min

        matches = AgentRouter.route(prompt, limit: limit)

        render json: {
          classification: {
            category: classification.category,
            subcategory: classification.subcategory,
            confidence: classification.confidence
          },
          matches: matches.map { |m| match_data(m) },
          meta: {
            total: matches.size,
            prompt_length: prompt.length
          }
        }
      end

      private

      def match_data(match)
        agent = match.agent
        {
          slug: agent.slug,
          name: agent.name,
          category: agent.category,
          score: match.score,
          reasons: match.reasons,
          agent_score: agent.decayed_score&.round(1).to_f,
          tier: agent.tier,
          description: agent.description&.truncate(200)
        }
      end
    end
  end
end
