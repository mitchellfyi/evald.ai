module Api
  module V1
    class ClaimsController < BaseController
      include ApiAuthenticatable

      def create
        agent = Agent.find(params[:agent_id])

        claim = agent.agent_claims.create!(
          user: current_user,
          verification_method: params[:method],
          verification_data: { token: SecureRandom.hex(16) },
          status: "pending"
        )

        render json: {
          claim: claim.as_json(only: [ :id, :verification_method, :status ]),
          verification_instructions: verification_instructions(claim)
        }, status: :created
      end

      def verify
        claim = AgentClaim.find(params[:id])

        if ClaimVerificationService.new(claim).verify
          render json: { status: "verified" }
        else
          render json: { status: "pending", message: "Verification not found" }
        end
      end

      private

      def verification_instructions(claim)
        case claim.verification_method
        when "dns_txt"
          "Add a TXT record: _evaled.yourdomain.com = #{claim.verification_data['token']}"
        when "github_file"
          "Create file .evaled/verify.txt containing: #{claim.verification_data['token']}"
        when "api_key"
          "Call our API with your agent's API key"
        end
      end
    end
  end
end
