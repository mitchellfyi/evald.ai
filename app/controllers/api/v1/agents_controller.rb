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
        agent = Agent.published.find_by!(slug: params[:agent_id])
        render json: score_response(agent)
      end

      def compare
        slugs = params[:agents].to_s.split(',').map(&:strip).first(5)
        agents = Agent.published.where(slug: slugs)
        
        render json: {
          task: params[:task],
          agents: agents.map { |a| agent_detail(a) },
          recommendation: recommend_agent(agents, params[:task])
        }
      end

      def search
        agents = Agent.published
        
        agents = agents.by_category(params[:capability]) if params[:capability].present?
        agents = agents.high_score(params[:min_score].to_i) if params[:min_score].present?
        
        if params[:q].present?
          agents = agents.where('name ILIKE ? OR description ILIKE ?', 
                                "%#{params[:q]}%", "%#{params[:q]}%")
        end
        
        render json: agents.limit(20).map { |a| agent_summary(a) }
      end

      private

      def agent_summary(agent)
        {
          agent: agent.slug,
          name: agent.name,
          category: agent.category,
          score: agent.decayed_score,
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
          score: agent.decayed_score,
          score_at_eval: agent.score_at_eval,
          tier0: agent.tier0_summary,
          tier1: agent.tier1_summary,
          last_verified: agent.last_verified_at&.iso8601,
          next_eval_scheduled: agent.next_eval_scheduled_at&.iso8601,
          claim_status: agent.claim_status
        }
      end

      def score_response(agent)
        {
          agent: agent.slug,
          score: agent.decayed_score,
          tier0: agent.tier0_summary,
          tier1: agent.tier1_summary,
          last_verified: agent.last_verified_at&.iso8601
        }
      end

      def recommend_agent(agents, task)
        # Simple recommendation based on score and category match
        best = agents.max_by { |a| a.decayed_score || 0 }
        return nil unless best
        
        {
          recommended: best.slug,
          reason: "Highest Evaled Score (#{best.decayed_score}) among compared agents"
        }
      end
    end
  end
end
