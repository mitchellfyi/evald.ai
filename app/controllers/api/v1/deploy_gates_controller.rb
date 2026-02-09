module Api
  module V1
    class DeployGatesController < BaseController
      # POST /api/v1/deploy_gates/check
      # Validates agent scores meet minimum threshold for deployment
      #
      # Params:
      #   agents: Array of agent slugs to check
      #   min_score: Minimum score threshold (0-100, default: 70)
      #
      # Returns:
      #   {
      #     pass: boolean,
      #     threshold: number,
      #     checked_at: ISO8601 timestamp,
      #     agents: [{ agent, score, pass, last_verified }],
      #     summary: "X/Y agents passed"
      #   }
      def check
        agent_slugs = Array(params[:agents])
        min_score = (params[:min_score] || 70).to_i

        if agent_slugs.empty?
          return render json: { error: "agents parameter is required" }, status: :bad_request
        end

        results = check_agents(agent_slugs, min_score)
        passed_count = results.count { |r| r[:pass] }
        all_passed = results.all? { |r| r[:pass] }

        render json: {
          pass: all_passed,
          threshold: min_score,
          checked_at: Time.current.iso8601,
          agents: results,
          summary: "#{passed_count}/#{results.size} agents passed (min_score: #{min_score})"
        }, status: all_passed ? :ok : :unprocessable_entity
      end

      private

      def check_agents(slugs, min_score)
        slugs.map do |slug|
          agent = Agent.published.find_by(slug: slug)

          if agent.nil?
            {
              agent: slug,
              score: nil,
              pass: false,
              error: "Agent not found",
              last_verified: nil
            }
          else
            score = agent.decayed_score || 0
            {
              agent: agent.slug,
              name: agent.name,
              score: score,
              pass: score >= min_score,
              last_verified: agent.last_verified_at&.iso8601
            }
          end
        end
      end
    end
  end
end
