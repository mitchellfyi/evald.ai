# frozen_string_literal: true
module AgentsHelper
  def score_color_class(score)
    return "text-gray-400" unless score

    case score.to_f
    when 90..100 then "text-green-600"
    when 80..89 then "text-green-500"
    when 70..79 then "text-yellow-600"
    when 60..69 then "text-yellow-500"
    when 50..59 then "text-orange-500"
    else "text-red-500"
    end
  end

  def score_bar_class(score)
    return "bg-gray-300" unless score

    case score.to_f
    when 90..100 then "bg-green-500"
    when 80..89 then "bg-green-400"
    when 70..79 then "bg-yellow-500"
    when 60..69 then "bg-yellow-400"
    when 50..59 then "bg-orange-500"
    else "bg-red-500"
    end
  end

  def confidence_badge_class(level)
    case level.to_s
    when "high" then "bg-green-100 text-green-700"
    when "medium" then "bg-yellow-100 text-yellow-700"
    when "low" then "bg-orange-100 text-orange-700"
    else "bg-gray-100 text-gray-500"
    end
  end

  def confidence_label(level)
    case level.to_s
    when "high" then "High Confidence"
    when "medium" then "Medium Confidence"
    when "low" then "Low Confidence"
    else "Insufficient Data"
    end
  end

  def confidence_tooltip(level)
    case level.to_s
    when "high"
      "Score based on comprehensive Tier 0 and Tier 1 evaluations with multiple recent runs."
    when "medium"
      "Score based on Tier 0 evaluation with partial Tier 1 data or recent evaluation activity."
    when "low"
      "Score based on Tier 0 passive signals only. No Tier 1 task evaluations completed."
    else
      "Minimal data available. This score may change significantly as more evaluations are completed."
    end
  end

  def tier_badge_class(tier)
    case tier.to_s
    when "platinum" then "bg-gradient-to-r from-slate-300 to-slate-400 text-slate-800"
    when "gold" then "bg-gradient-to-r from-yellow-300 to-yellow-400 text-yellow-800"
    when "silver" then "bg-gradient-to-r from-gray-200 to-gray-300 text-gray-700"
    when "bronze" then "bg-gradient-to-r from-orange-200 to-orange-300 text-orange-800"
    else "bg-gray-100 text-gray-500"
    end
  end

  def tier_label(tier)
    case tier.to_s
    when "platinum" then "⭐ Platinum"
    when "gold" then "🥇 Gold"
    when "silver" then "🥈 Silver"
    when "bronze" then "🥉 Bronze"
    else "Unrated"
    end
  end

  # Calculate and return trend indicator data for an agent's score
  def score_trend_indicator(agent)
    scores = agent.evaluations
      .completed
      .where.not(score: nil)
      .order(completed_at: :desc)
      .limit(10)
      .pluck(:score)
      .map(&:to_f)

    return { show: false } if scores.size < 2

    recent = scores.first(3)
    older = scores.last([scores.size / 2, 1].max)

    recent_avg = recent.sum / recent.size
    older_avg = older.sum / older.size
    diff = recent_avg - older_avg

    if diff > 3
      { show: true, icon: "↑", class: "text-green-500", label: "Improving" }
    elsif diff < -3
      { show: true, icon: "↓", class: "text-red-500", label: "Declining" }
    else
      { show: true, icon: "→", class: "text-gray-400", label: "Stable" }
    end
  end
end
