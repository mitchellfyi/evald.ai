# frozen_string_literal: true
class AgentsController < ApplicationController
  PER_PAGE = 25

  def index
    agents = Agent.published.order(score: :desc)

    if params[:category].present?
      agents = agents.by_category(params[:category])
    end

    if params[:min_score].present?
      agents = agents.high_score(params[:min_score].to_i)
    end

    @total_count = agents.count
    @page = (params[:page] || 1).to_i
    @total_pages = (@total_count.to_f / PER_PAGE).ceil
    @page = [[@page, 1].max, @total_pages].min if @total_pages > 0

    @agents = agents.offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
    @featured_agents = Agent.published.featured.order(score: :desc).limit(6)
    @categories = Agent::CATEGORIES
  end

  def show
    @agent = Agent.published.find_by!(slug: params[:id])
    @evaluations = @agent.evaluations.completed.recent.limit(10)
  end

  def compare
    slugs = params[:agents].to_s.split(",").map(&:strip).first(5)
    @agents = Agent.published.where(slug: slugs)
  end

  def score_history
    @agent = Agent.published.find_by!(slug: params[:id])

    # Get completed evaluations with scores, ordered by date
    evaluations = @agent.evaluations
      .completed
      .where.not(score: nil)
      .where.not(completed_at: nil)
      .order(completed_at: :asc)
      .select(:completed_at, :score, :tier)
      .limit(50)

    data = evaluations.map do |eval|
      {
        date: eval.completed_at.strftime("%Y-%m-%d"),
        score: eval.score.to_f.round(1),
        tier: eval.tier
      }
    end

    # Calculate trend
    trend = calculate_trend(evaluations.map(&:score).compact.map(&:to_f))

    render json: {
      data: data,
      trend: trend,
      current_score: @agent.decayed_score&.round(1)
    }
  end

  private

  def calculate_trend(scores)
    return "stable" if scores.size < 2

    recent = scores.last(5)
    older = scores.first([scores.size / 2, 1].max)

    recent_avg = recent.sum / recent.size
    older_avg = older.sum / older.size

    diff = recent_avg - older_avg

    if diff > 3
      "improving"
    elsif diff < -3
      "declining"
    else
      "stable"
    end
  end
end
