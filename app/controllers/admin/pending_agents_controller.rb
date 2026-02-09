# frozen_string_literal: true

module Admin
  class PendingAgentsController < BaseController
    before_action :set_pending_agent, only: [:show, :approve, :reject]

    def index
      @pending_agents = PendingAgent.recent
      @pending_agents = @pending_agents.where(status: params[:status]) if params[:status].present?
      @pending_agents = @pending_agents.where("confidence_score >= ?", params[:min_score].to_i) if params[:min_score].present?
    end

    def show
    end

    def approve
      @pending_agent.approve!(current_user)
      redirect_to admin_pending_agents_path, notice: "Agent '#{@pending_agent.name}' approved."
    end

    def reject
      @pending_agent.reject!(current_user, reason: params[:rejection_reason])
      redirect_to admin_pending_agents_path, notice: "Agent '#{@pending_agent.name}' rejected."
    end

    private

    def set_pending_agent
      @pending_agent = PendingAgent.find(params[:id])
    end
  end
end
