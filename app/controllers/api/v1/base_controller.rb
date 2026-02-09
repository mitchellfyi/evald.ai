module Api
  module V1
    class BaseController < ApplicationController
      skip_before_action :verify_authenticity_token
      
      before_action :set_default_format
      
      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from ActionController::ParameterMissing, with: :bad_request

      private

      def set_default_format
        request.format = :json
      end

      def not_found
        render json: { error: 'Not found' }, status: :not_found
      end

      def bad_request(exception)
        render json: { error: exception.message }, status: :bad_request
      end
    end
  end
end
