class BadgesController < ApplicationController
  def show
    @agent = Agent.find_by!(slug: params[:agent_id])
    
    # Cache for 1 hour
    expires_in 1.hour, public: true
    
    respond_to do |format|
      format.svg { render layout: false, content_type: 'image/svg+xml' }
      format.png { redirect_to shields_io_url }
    end
  end

  private

  def shields_io_url
    score = @agent.decayed_score || 'N/A'
    color = @agent.badge_color
    label = params[:label] || 'evaled'
    
    "https://img.shields.io/badge/#{label}-#{score}-#{color}?style=#{badge_style}"
  end

  def badge_style
    params[:style] || 'flat'
  end
end
