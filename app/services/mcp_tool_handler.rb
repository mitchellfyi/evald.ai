# frozen_string_literal: true

# Service that handles MCP (Model Context Protocol) tool execution.
# Maps MCP tool calls to Evald's trust registry data.
class McpToolHandler
  PROTOCOL_VERSION = "2024-11-05"

  TOOLS = [
    {
      name: "get_agent_score",
      description: "Get the Evald trust score for an AI agent. Returns composite score, confidence level, score breakdown by tier, and decay status.",
      inputSchema: {
        type: "object",
        properties: {
          agent_id: { type: "string", description: "Agent slug identifier" },
          agent_name: { type: "string", description: "Agent name (alternative to agent_id)" }
        }
      }
    },
    {
      name: "compare_agents",
      description: "Compare multiple AI agents side-by-side with per-dimension score breakdown and recommendation for a given task domain.",
      inputSchema: {
        type: "object",
        properties: {
          agents: { type: "array", items: { type: "string" }, description: "Array of agent slug identifiers to compare (max 5)" },
          task_domain: { type: "string", description: "Optional task domain for recommendation (e.g., 'coding', 'research')" }
        },
        required: ["agents"]
      }
    },
    {
      name: "get_agent_profile",
      description: "Get full profile data for an AI agent including builder info, score trend, capabilities, tier details, and claim status.",
      inputSchema: {
        type: "object",
        properties: {
          agent_id: { type: "string", description: "Agent slug identifier" }
        },
        required: ["agent_id"]
      }
    },
    {
      name: "check_trust_threshold",
      description: "Check if an agent meets a minimum trust score threshold. Use as an automated gate before proceeding with an agent interaction.",
      inputSchema: {
        type: "object",
        properties: {
          agent_id: { type: "string", description: "Agent slug identifier" },
          minimum_score: { type: "number", description: "Minimum required Evald Score (0-100)" },
          required_tiers: { type: "array", items: { type: "string" }, description: "Optional tier data requirements (e.g., ['tier0', 'tier1'])" }
        },
        required: ["agent_id", "minimum_score"]
      }
    },
    {
      name: "search_agents",
      description: "Search for AI agents by capability, minimum score, domain, or verification status. Returns matching agents sorted by score.",
      inputSchema: {
        type: "object",
        properties: {
          capability: { type: "string", description: "Filter by agent category/capability (e.g., 'coding', 'research', 'workflow')" },
          min_score: { type: "number", description: "Minimum Evald Score filter" },
          domain: { type: "string", description: "Task domain to search within" },
          verified_only: { type: "boolean", description: "Only return verified agents" },
          limit: { type: "number", description: "Maximum results to return (default: 20, max: 50)" }
        }
      }
    },
    {
      name: "report_interaction",
      description: "Report an interaction outcome with another agent. Reports from agents with higher Evald scores carry more weight in the reputation system.",
      inputSchema: {
        type: "object",
        properties: {
          reporter_agent_id: { type: "string", description: "Slug of the reporting agent" },
          target_agent_id: { type: "string", description: "Slug of the agent being reported on" },
          interaction_type: { type: "string", description: "Type of interaction (e.g., 'delegation', 'collaboration', 'query', 'task_execution')" },
          outcome: { type: "string", description: "Description of the interaction outcome" },
          success: { type: "boolean", description: "Whether the interaction was successful" },
          notes: { type: "string", description: "Optional additional notes" }
        },
        required: ["reporter_agent_id", "target_agent_id", "interaction_type", "outcome", "success"]
      }
    }
  ].freeze

  def server_info
    {
      name: "evald-mcp-server",
      version: "1.0.0"
    }
  end

  def server_capabilities
    { tools: {} }
  end

  def list_tools
    TOOLS
  end

  def call_tool(name, arguments)
    case name
    when "get_agent_score"
      handle_get_agent_score(arguments)
    when "compare_agents"
      handle_compare_agents(arguments)
    when "get_agent_profile"
      handle_get_agent_profile(arguments)
    when "check_trust_threshold"
      handle_check_trust_threshold(arguments)
    when "search_agents"
      handle_search_agents(arguments)
    when "report_interaction"
      handle_report_interaction(arguments)
    else
      error_content("Unknown tool: #{name}")
    end
  end

  private

  def handle_get_agent_score(args)
    agent = find_agent(args)
    return agent_not_found_content(args) unless agent

    result = {
      agent_id: agent.slug,
      name: agent.name,
      score: agent.decayed_score&.to_f,
      score_at_eval: agent.score_at_eval&.to_f,
      confidence: confidence_level(agent),
      last_verified: agent.last_verified_at&.iso8601,
      tier0: agent.tier0_summary,
      tier1: agent.tier1_summary,
      decay_status: {
        rate: agent.decay_rate,
        current_score: agent.decayed_score&.to_f,
        original_score: agent.score_at_eval&.to_f
      }
    }

    success_content(result)
  end

  def handle_compare_agents(args)
    slugs = Array(args["agents"]).first(5)
    return error_content("At least two agent IDs are required") if slugs.size < 2

    agents = Agent.published.where(slug: slugs)
    return error_content("No matching agents found") if agents.empty?

    task_domain = args["task_domain"]

    result = {
      task_domain: task_domain,
      agents: agents.map { |a| agent_comparison_detail(a) },
      recommendation: build_recommendation(agents, task_domain)
    }

    success_content(result)
  end

  def handle_get_agent_profile(args)
    agent = Agent.published.find_by(slug: args["agent_id"])
    return agent_not_found_content(args) unless agent

    interaction_count = AgentInteraction.for_target(agent).count if defined?(AgentInteraction) && AgentInteraction.table_exists?

    result = {
      agent_id: agent.slug,
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
      safety_level: agent.safety_level,
      tier0: agent.tier0_summary,
      tier1: agent.tier1_summary,
      claim_status: agent.claim_status,
      verified: agent.verified?,
      last_verified: agent.last_verified_at&.iso8601,
      next_eval_scheduled: agent.next_eval_scheduled_at&.iso8601,
      interaction_count: interaction_count || 0
    }

    success_content(result)
  end

  def handle_check_trust_threshold(args)
    agent = Agent.published.find_by(slug: args["agent_id"])
    return agent_not_found_content(args) unless agent

    minimum_score = args["minimum_score"].to_f
    required_tiers = Array(args["required_tiers"])
    current_score = agent.decayed_score&.to_f || 0

    missing = []
    missing << "score_below_threshold (#{current_score} < #{minimum_score})" if current_score < minimum_score

    required_tiers.each do |tier|
      case tier
      when "tier0"
        missing << "tier0_data_missing" if agent.tier0_summary.compact.empty?
      when "tier1"
        missing << "tier1_data_missing" if agent.tier1_summary.compact.empty?
      end
    end

    result = {
      agent_id: agent.slug,
      passes: missing.empty?,
      current_score: current_score,
      minimum_score: minimum_score,
      missing_requirements: missing.presence
    }

    success_content(result)
  end

  def handle_search_agents(args)
    agents = Agent.published.order(score: :desc)

    agents = agents.by_category(args["capability"]) if args["capability"].present?
    agents = agents.high_score(args["min_score"].to_i) if args["min_score"].present?
    agents = agents.where(claim_status: "verified") if args["verified_only"]

    if args["domain"].present?
      agents = agents.where("name ILIKE ? OR description ILIKE ? OR category ILIKE ?",
                            "%#{args["domain"]}%", "%#{args["domain"]}%", "%#{args["domain"]}%")
    end

    limit = [args["limit"]&.to_i || 20, 50].min
    agents = agents.limit(limit)

    result = {
      count: agents.size,
      agents: agents.map { |a| agent_search_result(a) }
    }

    success_content(result)
  end

  def handle_report_interaction(args)
    reporter = Agent.published.find_by(slug: args["reporter_agent_id"])
    return error_content("Reporter agent not found: #{args["reporter_agent_id"]}") unless reporter

    target = Agent.published.find_by(slug: args["target_agent_id"])
    return error_content("Target agent not found: #{args["target_agent_id"]}") unless target

    interaction = AgentInteraction.create!(
      reporter_agent: reporter,
      target_agent: target,
      interaction_type: args["interaction_type"],
      outcome: args["outcome"],
      success: args["success"],
      notes: args["notes"],
      reporter_score_at_time: reporter.decayed_score,
      target_score_at_time: target.decayed_score
    )

    result = {
      recorded: true,
      interaction_id: interaction.id,
      reporter: reporter.slug,
      target: target.slug,
      total_interactions: AgentInteraction.for_target(target).count
    }

    success_content(result)
  end

  # Helper methods

  def find_agent(args)
    if args["agent_id"].present?
      Agent.published.find_by(slug: args["agent_id"])
    elsif args["agent_name"].present?
      Agent.published.where("name ILIKE ?", args["agent_name"]).first
    end
  end

  def confidence_level(agent)
    has_tier0 = agent.tier0_summary.compact.any?
    has_tier1 = agent.tier1_summary.compact.any?
    has_recent_eval = agent.last_verified_at.present? && agent.last_verified_at > 30.days.ago

    if has_tier0 && has_tier1 && has_recent_eval
      "high"
    elsif has_tier0 && has_recent_eval
      "medium"
    elsif has_tier0
      "low"
    else
      "minimal"
    end
  end

  def agent_comparison_detail(agent)
    {
      agent_id: agent.slug,
      name: agent.name,
      category: agent.category,
      score: agent.decayed_score&.to_f,
      tier: agent.tier,
      tier0: agent.tier0_summary,
      tier1: agent.tier1_summary,
      last_verified: agent.last_verified_at&.iso8601
    }
  end

  def agent_search_result(agent)
    {
      agent_id: agent.slug,
      name: agent.name,
      category: agent.category,
      score: agent.decayed_score&.to_f,
      verified: agent.verified?,
      last_verified: agent.last_verified_at&.iso8601
    }
  end

  def build_recommendation(agents, task_domain)
    best = if task_domain.present?
             domain_agents = agents.select { |a| a.category == task_domain }
             domain_agents.any? ? domain_agents.max_by { |a| a.decayed_score || 0 } : agents.max_by { |a| a.decayed_score || 0 }
           else
             agents.max_by { |a| a.decayed_score || 0 }
           end

    return nil unless best

    {
      recommended: best.slug,
      reason: "Highest Evald Score (#{best.decayed_score&.to_f}) among compared agents" +
              (task_domain.present? ? " for #{task_domain} tasks" : "")
    }
  end

  def success_content(result)
    [{ type: "text", text: result.to_json }]
  end

  def error_content(message)
    [{ type: "text", text: { error: message }.to_json, isError: true }]
  end

  def agent_not_found_content(args)
    identifier = args["agent_id"] || args["agent_name"] || "unknown"
    error_content("Agent not found: #{identifier}")
  end
end
