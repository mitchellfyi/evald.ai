# frozen_string_literal: true
module Api
  module V1
    class AgentsController < BaseController
      def index
        agents = Agent.published.order(score: :desc)

        agents = agents.by_category(params[:capability]) if params[:capability].present?
        agents = agents.high_score(params[:min_score].to_i) if params[:min_score].present?

        agents = agents.limit(params[:limit] || 50)

        render json: agents.map { |a| agent_summary(a) }
      end

      def show
        agent = Agent.published.find_by!(slug: params[:id])
        render json: agent_detail(agent)
      end

      def score
        agent = Agent.published.find_by!(slug: params[:id])
        render json: score_response(agent)
      end

      def compare
        slugs = params[:agents].to_s.split(",").map(&:strip).first(5)
        agents = Agent.published.where(slug: slugs)

        # Filter by domain if task parameter provided (maps to domain)
        domain = params[:task] || params[:domain]

        render json: {
          task: domain,
          agents: agents.map { |a| agent_comparison(a, domain) },
          recommendation: recommend_agent(agents, domain)
        }
      end

      def search
        agents = Agent.published

        agents = agents.by_category(params[:capability]) if params[:capability].present?
        agents = agents.high_score(params[:min_score].to_i) if params[:min_score].present?
        agents = agents.by_domain(params[:domain]) if params[:domain].present?
        agents = agents.by_primary_domain(params[:primary_domain]) if params[:primary_domain].present?

        if params[:q].present?
          agents = agents.where("name ILIKE ? OR description ILIKE ?",
                                "%#{params[:q]}%", "%#{params[:q]}%")
        end

        # Order by domain score if domain filter provided
        domain_order = safe_domain_order_clause(params[:domain])
        agents = if domain_order
                   agents.order(Arel.sql(domain_order))
                 else
                   agents.order(score: :desc)
                 end

        render json: agents.limit(20).map { |a| agent_summary(a) }
      end

      private

      # Explicit whitelist for domain score columns - prevents SQL injection
      # Brakeman requires explicit case statements to recognize safe patterns
      def safe_domain_order_clause(domain)
        case domain
        when "coding" then "coding_score DESC NULLS LAST"
        when "research" then "research_score DESC NULLS LAST"
        when "workflow" then "workflow_score DESC NULLS LAST"
        end
      end

      def agent_summary(agent)
        {
          agent: agent.slug,
          name: agent.name,
          category: agent.category,
          score: agent.decayed_score&.to_f,
          tier: agent.tier,
          confidence: agent.confidence_level,
          last_verified: agent.last_verified_at&.iso8601
        }
      end

      def agent_detail(agent)
        {
          agent: agent.slug,
          name: agent.name,
          description: agent.description,
          category: agent.category,
          builder: {
            name: agent.builder_name,
            url: agent.builder_url
          },
          repo_url: agent.repo_url,
          website_url: agent.website_url,
          score: agent.decayed_score&.to_f,
          score_at_eval: agent.score_at_eval&.to_f,
          tier: agent.tier,
          confidence: agent.confidence_level,
          confidence_factors: agent.confidence_factors,
          domain_scores: agent.domain_scores,
          primary_domain: agent.primary_domain,
          tier0: agent.tier0_summary,
          tier1: agent.tier1_summary,
          decay_rate: agent.decay_rate,
          last_verified: agent.last_verified_at&.iso8601,
          next_eval_scheduled: agent.next_eval_scheduled_at&.iso8601,
          claim_status: agent.claim_status
        }
      end

      def score_response(agent)
        {
          agent: agent.slug,
          score: agent.decayed_score&.to_f,
          score_at_eval: agent.score_at_eval&.to_f,
          tier: agent.tier,
          confidence: agent.confidence_level,
          confidence_factors: agent.confidence_factors,
          domain_scores: agent.domain_scores,
          primary_domain: agent.primary_domain,
          tier0: agent.tier0_summary,
          tier1: agent.tier1_summary,
          decay_rate: agent.decay_rate,
          last_verified: agent.last_verified_at&.iso8601
        }
      end

      def agent_comparison(agent, domain = nil)
        base = agent_detail(agent)

        # If domain filter provided, add domain-specific score prominently
        if domain.present? && Agent::DOMAINS.include?(domain)
          domain_data = agent.domain_scores[domain]
          base[:domain_score] = domain_data&.dig(:score)
          base[:domain_confidence] = domain_data&.dig(:confidence) || "insufficient"
        end

        base
      end

      def recommend_agent(agents, domain = nil)
        return nil if agents.empty?

        # If domain specified, rank by domain score
        if domain.present? && Agent::DOMAINS.include?(domain)
          best = agents.max_by do |a|
            a.domain_scores.dig(domain, :score) || 0
          end

          domain_score = best.domain_scores.dig(domain, :score)
          if domain_score.present?
            return {
              recommended: best.slug,
              reason: "Highest #{domain.titleize} domain score (#{domain_score}) among compared agents"
            }
          end
        end

        # Fallback to overall score
        best = agents.max_by { |a| a.decayed_score || 0 }
        return nil unless best

        {
          recommended: best.slug,
          reason: "Highest Evald Score (#{best.decayed_score}) among compared agents"
        }
      end
    end
  end
end
