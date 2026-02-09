# frozen_string_literal: true
module Builder
  class BaseController < ApplicationController
    before_action :authenticate_user!

    private

    def authenticate_user!
      unless current_user
        redirect_to new_user_session_path, alert: "Please sign in to access the builder dashboard."
      end
    end
  end
end
