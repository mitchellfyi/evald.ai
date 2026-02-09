module ApiAuthenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_api_key!
  end

  private

  def authenticate_api_key!
    token = request.headers["Authorization"]&.remove("Bearer ")
    @current_api_key = ApiKey.active.find_by(token: token)

    unless @current_api_key
      render json: { error: "Invalid or expired API key" }, status: :unauthorized
      return
    end

    @current_api_key.touch_last_used!
    @current_user = @current_api_key.user
  end

  def current_api_key
    @current_api_key
  end

  def current_user
    @current_user
  end
end
