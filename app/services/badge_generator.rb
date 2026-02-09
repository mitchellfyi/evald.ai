# frozen_string_literal: true

class BadgeGenerator
  COLORS = {
    # Score colors (gradient based on percentage)
    excellent: "#4c1",      # Green - 80-100
    good: "#97ca00",        # Yellow-green - 60-79
    moderate: "#dfb317",    # Yellow - 40-59
    poor: "#fe7d37",        # Orange - 20-39
    critical: "#e05d44",    # Red - 0-19

    # Tier colors
    platinum: "#e5e4e2",
    gold: "#ffd700",
    silver: "#c0c0c0",
    bronze: "#cd7f32",
    unrated: "#9f9f9f",

    # Safety colors
    safe: "#4c1",
    caution: "#dfb317",
    warning: "#fe7d37",
    danger: "#e05d44",

    # Certification
    certified: "#4c1",
    pending: "#dfb317",
    uncertified: "#9f9f9f"
  }.freeze

  class << self
    def generate_svg(agent, type:, style:)
      case type
      when "score"
        generate_score_badge(agent, style)
      when "tier"
        generate_tier_badge(agent, style)
      when "safety"
        generate_safety_badge(agent, style)
      when "certification"
        generate_certification_badge(agent, style)
      else
        generate_score_badge(agent, style)
      end
    end

    def generate_error_svg(message)
      render_badge(
        label: "evaled",
        value: message,
        color: "#9f9f9f",
        style: "flat"
      )
    end

    private

    def generate_score_badge(agent, style)
      score = agent.overall_score || 0
      color = score_color(score)

      render_badge(
        label: "evaled",
        value: "#{score.round}%",
        color: color,
        style: style
      )
    end

    def generate_tier_badge(agent, style)
      tier = agent.tier || "unrated"
      color = COLORS[tier.downcase.to_sym] || COLORS[:unrated]

      render_badge(
        label: "evaled tier",
        value: tier.capitalize,
        color: color,
        style: style
      )
    end

    def generate_safety_badge(agent, style)
      safety = agent.safety_level || "unknown"
      color = safety_color(safety)

      render_badge(
        label: "safety",
        value: safety.capitalize,
        color: color,
        style: style
      )
    end

    def generate_certification_badge(agent, style)
      certified = agent.certified?
      status = certified ? "certified" : "uncertified"
      color = COLORS[status.to_sym]

      render_badge(
        label: "evaled",
        value: certified ? "Certified" : "Uncertified",
        color: color,
        style: style
      )
    end

    def score_color(score)
      case score
      when 80..100 then COLORS[:excellent]
      when 60...80 then COLORS[:good]
      when 40...60 then COLORS[:moderate]
      when 20...40 then COLORS[:poor]
      else COLORS[:critical]
      end
    end

    def safety_color(safety)
      case safety.to_s.downcase
      when "safe", "high" then COLORS[:safe]
      when "caution", "medium" then COLORS[:caution]
      when "warning", "low" then COLORS[:warning]
      when "danger", "critical" then COLORS[:danger]
      else COLORS[:unrated]
      end
    end

    def render_badge(label:, value:, color:, style:)
      case style
      when "plastic"
        render_plastic_badge(label, value, color)
      when "for-the-badge"
        render_for_the_badge(label, value, color)
      else
        render_flat_badge(label, value, color)
      end
    end

    def render_flat_badge(label, value, color)
      label_width = calculate_text_width(label)
      value_width = calculate_text_width(value)
      total_width = label_width + value_width

      <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" width="#{total_width}" height="20">
          <linearGradient id="b" x2="0" y2="100%">
            <stop offset="0" stop-color="#bbb" stop-opacity=".1"/>
            <stop offset="1" stop-opacity=".1"/>
          </linearGradient>
          <clipPath id="a">
            <rect width="#{total_width}" height="20" rx="3" fill="#fff"/>
          </clipPath>
          <g clip-path="url(#a)">
            <rect width="#{label_width}" height="20" fill="#555"/>
            <rect x="#{label_width}" width="#{value_width}" height="20" fill="#{color}"/>
            <rect width="#{total_width}" height="20" fill="url(#b)"/>
          </g>
          <g fill="#fff" text-anchor="middle" font-family="DejaVu Sans,Verdana,Geneva,sans-serif" font-size="11">
            <text x="#{label_width / 2}" y="15" fill="#010101" fill-opacity=".3">#{escape_xml(label)}</text>
            <text x="#{label_width / 2}" y="14">#{escape_xml(label)}</text>
            <text x="#{label_width + (value_width / 2)}" y="15" fill="#010101" fill-opacity=".3">#{escape_xml(value)}</text>
            <text x="#{label_width + (value_width / 2)}" y="14">#{escape_xml(value)}</text>
          </g>
        </svg>
      SVG
    end

    def render_plastic_badge(label, value, color)
      label_width = calculate_text_width(label)
      value_width = calculate_text_width(value)
      total_width = label_width + value_width

      <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" width="#{total_width}" height="18">
          <linearGradient id="b" x2="0" y2="100%">
            <stop offset="0" stop-color="#fff" stop-opacity=".7"/>
            <stop offset=".1" stop-color="#aaa" stop-opacity=".1"/>
            <stop offset=".9" stop-opacity=".3"/>
            <stop offset="1" stop-opacity=".5"/>
          </linearGradient>
          <clipPath id="a">
            <rect width="#{total_width}" height="18" rx="4" fill="#fff"/>
          </clipPath>
          <g clip-path="url(#a)">
            <rect width="#{label_width}" height="18" fill="#555"/>
            <rect x="#{label_width}" width="#{value_width}" height="18" fill="#{color}"/>
            <rect width="#{total_width}" height="18" fill="url(#b)"/>
          </g>
          <g fill="#fff" text-anchor="middle" font-family="DejaVu Sans,Verdana,Geneva,sans-serif" font-size="11">
            <text x="#{label_width / 2}" y="13" fill="#010101" fill-opacity=".3">#{escape_xml(label)}</text>
            <text x="#{label_width / 2}" y="12">#{escape_xml(label)}</text>
            <text x="#{label_width + (value_width / 2)}" y="13" fill="#010101" fill-opacity=".3">#{escape_xml(value)}</text>
            <text x="#{label_width + (value_width / 2)}" y="12">#{escape_xml(value)}</text>
          </g>
        </svg>
      SVG
    end

    def render_for_the_badge(label, value, color)
      label_upper = label.upcase
      value_upper = value.upcase
      label_width = calculate_text_width(label_upper, large: true)
      value_width = calculate_text_width(value_upper, large: true)
      total_width = label_width + value_width

      <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" width="#{total_width}" height="28">
          <clipPath id="a">
            <rect width="#{total_width}" height="28" rx="3" fill="#fff"/>
          </clipPath>
          <g clip-path="url(#a)">
            <rect width="#{label_width}" height="28" fill="#555"/>
            <rect x="#{label_width}" width="#{value_width}" height="28" fill="#{color}"/>
          </g>
          <g fill="#fff" text-anchor="middle" font-family="DejaVu Sans,Verdana,Geneva,sans-serif" font-size="10" font-weight="bold">
            <text x="#{label_width / 2}" y="18">#{escape_xml(label_upper)}</text>
            <text x="#{label_width + (value_width / 2)}" y="18">#{escape_xml(value_upper)}</text>
          </g>
        </svg>
      SVG
    end

    def calculate_text_width(text, large: false)
      # Approximate character width calculation
      char_width = large ? 7.5 : 6.5
      padding = large ? 20 : 12
      (text.length * char_width + padding).round
    end

    def escape_xml(text)
      text.to_s
          .gsub("&", "&amp;")
          .gsub("<", "&lt;")
          .gsub(">", "&gt;")
          .gsub('"', "&quot;")
          .gsub("'", "&#39;")
    end
  end
end
