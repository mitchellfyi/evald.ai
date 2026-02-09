module AgentsHelper
  def score_color_class(score)
    return 'text-gray-400' unless score

    case score.to_f
    when 90..100 then 'text-green-600'
    when 80..89 then 'text-green-500'
    when 70..79 then 'text-yellow-600'
    when 60..69 then 'text-yellow-500'
    when 50..59 then 'text-orange-500'
    else 'text-red-500'
    end
  end

  def score_bar_class(score)
    return 'bg-gray-300' unless score

    case score.to_f
    when 90..100 then 'bg-green-500'
    when 80..89 then 'bg-green-400'
    when 70..79 then 'bg-yellow-500'
    when 60..69 then 'bg-yellow-400'
    when 50..59 then 'bg-orange-500'
    else 'bg-red-500'
    end
  end
end
