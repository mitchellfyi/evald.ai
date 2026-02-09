class AgentsController < ApplicationController
  def index
    @agents = Agent.published.order(score: :desc)
    
    if params[:category].present?
      @agents = @agents.by_category(params[:category])
    end
    
    if params[:min_score].present?
      @agents = @agents.high_score(params[:min_score].to_i)
    end
    
    @featured_agents = Agent.published.featured.order(score: :desc).limit(6)
    @categories = Agent::CATEGORIES
  end

  def show
    @agent = Agent.published.find_by!(slug: params[:id])
    @evaluations = @agent.evaluations.completed.recent.limit(10)
  end

  def compare
    slugs = params[:agents].to_s.split(',').map(&:strip).first(5)
    @agents = Agent.published.where(slug: slugs)
  end
end
