# frozen_string_literal: true

class BadgesController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [ :show ]

  VALID_STYLES = %w[flat plastic for-the-badge].freeze
  VALID_TYPES = %w[score tier safety certification].freeze

  def show
    agent = Agent.find_by(name: params[:agent_name])

    unless agent
      return render plain: not_found_svg, content_type: "image/svg+xml", status: :not_found
    end

    style = params[:style].to_s.downcase
    style = "flat" unless VALID_STYLES.include?(style)

    badge_type = params[:type].to_s.downcase
    badge_type = "score" unless VALID_TYPES.include?(badge_type)

    svg = BadgeGenerator.generate_svg(agent, type: badge_type, style: style)

    set_cache_headers
    render plain: svg, content_type: "image/svg+xml"
  end

  private

  def set_cache_headers
    expires_in 1.hour, public: true
    response.headers["Cache-Control"] = "public, max-age=3600, s-maxage=3600"
    response.headers["Surrogate-Control"] = "max-age=86400"
  end

  def not_found_svg
    BadgeGenerator.generate_error_svg("Agent Not Found")
  end
end
