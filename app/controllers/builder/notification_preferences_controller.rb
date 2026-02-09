# frozen_string_literal: true
module Builder
  class NotificationPreferencesController < BaseController
    before_action :set_agent
    before_action :authorize_agent

    def edit
      @notification_preference = @agent.notification_preferences.find_or_initialize_by(user: current_user)
    end

    def update
      @notification_preference = @agent.notification_preferences.find_or_initialize_by(user: current_user)

      if @notification_preference.update(notification_params)
        redirect_to edit_builder_agent_path(@agent), notice: "Notification preferences updated."
      else
        render "builder/agents/edit", status: :unprocessable_entity
      end
    end

    private

    def set_agent
      @agent = Agent.find_by!(slug: params[:agent_id])
    end

    def authorize_agent
      unless @agent.claimed_by_user == current_user
        redirect_to builder_root_path, alert: "You don't have permission to manage this agent."
      end
    end

    def notification_params
      params.require(:notification_preference).permit(
        :score_changes, :new_eval_results,
        :comparison_mentions, :email_enabled
      )
    end
  end
end
