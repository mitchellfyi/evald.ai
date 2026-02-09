# frozen_string_literal: true
module Builder
  class DashboardController < BaseController
    def index
      @claimed_agents = current_user.claimed_agents.order(:name)
    end
  end
end
