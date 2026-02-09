# frozen_string_literal: true
class PagesController < ApplicationController
  def home
    @featured_agents = Agent.published.featured.order(score: :desc).limit(6)
    @recent_agents = Agent.published.recently_verified.order(last_verified_at: :desc).limit(8)
    @top_agents = Agent.published.order(score: :desc).limit(10)
  end

  def about
  end

  def methodology
  end

  def badges
  end
end
