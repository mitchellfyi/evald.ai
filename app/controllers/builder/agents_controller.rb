# frozen_string_literal: true
module Builder
  class AgentsController < BaseController
    before_action :set_agent
    before_action :authorize_agent

    def edit
      @notification_preference = @agent.notification_preferences.find_or_initialize_by(user: current_user)
    end

    def update
      if @agent.update(builder_agent_params)
        redirect_to edit_builder_agent_path(@agent), notice: "Profile updated successfully."
      else
        @notification_preference = @agent.notification_preferences.find_or_initialize_by(user: current_user)
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_agent
      @agent = Agent.find_by!(slug: params[:id])
    end

    def authorize_agent
      unless @agent.claimed_by_user == current_user
        redirect_to builder_root_path, alert: "You don't have permission to edit this agent."
      end
    end

    # Only allow builder-editable fields
    def builder_agent_params
      params.require(:agent).permit(
        :description, :tagline, :use_case,
        :documentation_url, :changelog_url, :demo_url
      )
    end
  end
end
