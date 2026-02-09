# frozen_string_literal: true

class RecommendationEngine
  def self.recommend_for_capability(capability, limit: 5)
    new.recommend_for_capability(capability, limit: limit)
  end

  def self.find_similar_agents(agent)
    new.find_similar_agents(agent)
  end

  def recommend_for_capability(capability, limit: 5)
    return [] if capability.blank?

    Agent.published
         .by_category(capability)
         .order(score: :desc)
         .limit(limit)
         .map { |a| recommendation_data(a, capability) }
  end

  def find_similar_agents(agent, limit: 5)
    return [] if agent.nil?

    # Find agents with overlapping categories and similar scores
    similar = Agent.published
                   .where.not(id: agent.id)
                   .where("categories && ARRAY[?]::varchar[]", agent.categories.to_a)
                   .order(Arel.sql("ABS(score - #{agent.score.to_i})"))
                   .limit(limit)

    similar.map { |a| similarity_data(a, agent) }
  end

  private

  def recommendation_data(agent, capability)
    {
      slug: agent.slug,
      name: agent.name,
      provider: agent.provider,
      score: agent.score,
      tier: agent.tier,
      match_reason: "Top performer for #{capability}",
      categories: agent.categories
    }
  end

  def similarity_data(similar_agent, reference_agent)
    shared = (similar_agent.categories.to_a & reference_agent.categories.to_a)

    {
      slug: similar_agent.slug,
      name: similar_agent.name,
      provider: similar_agent.provider,
      score: similar_agent.score,
      tier: similar_agent.tier,
      shared_categories: shared,
      score_difference: (similar_agent.score - reference_agent.score).round(1)
    }
  end
end
