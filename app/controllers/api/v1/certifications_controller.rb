# frozen_string_literal: true

module Api
  module V1
    class CertificationsController < BaseController
      # GET /api/v1/certifications/:id
      # Verification endpoint - check if a certification is valid
      def show
        certification = Certification.find(params[:id])

        render json: {
          id: certification.id,
          agent_id: certification.agent_id,
          agent_name: certification.agent.name,
          tier: certification.tier,
          status: certification.status,
          valid: certification.valid_certification?,
          applied_at: certification.applied_at,
          reviewed_at: certification.reviewed_at,
          expires_at: certification.expires_at
        }
      end

      # POST /api/v1/certifications
      # Apply for certification
      def create
        agent = Agent.find(params[:agent_id])
        certification = agent.certifications.new(certification_params)

        if certification.save
          render json: {
            id: certification.id,
            agent_id: certification.agent_id,
            tier: certification.tier,
            status: certification.status,
            applied_at: certification.applied_at,
            message: "Certification application submitted successfully"
          }, status: :created
        else
          render json: { errors: certification.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def certification_params
        params.require(:certification).permit(:tier)
      end
    end
  end
end
