# frozen_string_literal: true
module Admin
  class AgentsController < BaseController
    before_action :set_agent, only: [:show, :edit, :update, :destroy, :run_tier0, :run_tier1, :run_tier2]

    def index
      @agents = Agent.all.order(stars: :desc, created_at: :desc)
    end

    def show
    end

    def edit
    end

    def update
      if @agent.update(agent_params)
        redirect_to admin_agent_path(@agent), notice: "Agent updated successfully."
      else
        render "admin/agents/edit", status: :unprocessable_content
      end
    end

    def destroy
      @agent.destroy
      redirect_to admin_agents_path, notice: "Agent deleted successfully."
    end

    # Manual evaluation triggers - Tier 2 evals are admin-only
    def run_tier0
      Tier0EvaluationJob.perform_later(@agent.id)
      redirect_to admin_agent_path(@agent), notice: "Tier 0 evaluation queued."
    end

    def run_tier1
      Tier1EvaluationJob.perform_later(@agent.id)
      redirect_to admin_agent_path(@agent), notice: "Tier 1 evaluation queued."
    end

    def run_tier2
      Tier2EvaluationJob.perform_later(@agent.id)
      redirect_to admin_agent_path(@agent), notice: "Tier 2 safety evaluation queued."
    end

    private

    def set_agent
      @agent = Agent.find_by!(slug: params[:id])
    end

    def agent_params
      params.expect(agent: [:name, :slug, :description, :repo_url, :category, tag_ids: []])
    end
  end
end
