# frozen_string_literal: true
require "test_helper"

class Api::V1::McpControllerTest < ActionDispatch::IntegrationTest
  setup do
    @agent1 = create(:agent, :published, :with_score, name: "Alpha Agent", slug: "alpha-agent", category: "coding")
    @agent2 = create(:agent, :published, :with_score, name: "Beta Agent", slug: "beta-agent", category: "research", score: 85.0, score_at_eval: 85.0)
    @agent3 = create(:agent, :published, :with_score, name: "Gamma Agent", slug: "gamma-agent", category: "coding", score: 60.0, score_at_eval: 60.0)
    @api_key = create(:api_key)
  end

  # ============================================
  # Authentication Tests
  # ============================================

  test "returns unauthorized without API key" do
    post api_v1_mcp_url,
         params: { jsonrpc: "2.0", id: 1, method: "ping" }.to_json,
         headers: { "CONTENT_TYPE" => "application/json" }

    assert_response :unauthorized
  end

  # ============================================
  # Protocol Tests
  # ============================================

  test "returns parse error for invalid JSON" do
    post api_v1_mcp_url, params: "{invalid", headers: auth_headers.merge("RAW_POST_DATA" => "{invalid")

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal(-32700, json["error"]["code"])
  end

  test "returns invalid request for missing jsonrpc version" do
    post_mcp({ method: "initialize" })

    json = JSON.parse(response.body)
    assert_equal(-32600, json["error"]["code"])
  end

  test "returns method not found for unknown method" do
    post_mcp({ jsonrpc: "2.0", id: 1, method: "unknown/method" })

    json = JSON.parse(response.body)
    assert_equal(-32601, json["error"]["code"])
  end

  test "handles ping method" do
    post_mcp({ jsonrpc: "2.0", id: 1, method: "ping" })

    json = JSON.parse(response.body)
    assert_equal "2.0", json["jsonrpc"]
    assert_equal 1, json["id"]
    assert_equal({}, json["result"])
  end

  test "returns invalid request for non-object batch element" do
    post api_v1_mcp_url,
         params: [
           "not an object",
           { jsonrpc: "2.0", id: 1, method: "ping" }
         ].to_json,
         headers: auth_headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_kind_of Array, json
    # First element should be an error with nil id
    assert_equal(-32600, json[0]["error"]["code"])
    assert_nil json[0]["id"]
  end

  test "returns invalid params for non-object arguments" do
    post_mcp({
      jsonrpc: "2.0",
      id: 1,
      method: "tools/call",
      params: { name: "get_agent_score", arguments: "not-an-object" }
    })

    json = JSON.parse(response.body)
    assert_equal(-32602, json["error"]["code"])
    assert_match(/arguments must be an object/, json["error"]["message"])
  end

  # ============================================
  # initialize
  # ============================================

  test "initialize returns server info and capabilities" do
    post_mcp({ jsonrpc: "2.0", id: 1, method: "initialize", params: { protocolVersion: "2024-11-05", capabilities: {} } })

    json = JSON.parse(response.body)
    assert_equal "2.0", json["jsonrpc"]
    assert_equal 1, json["id"]
    assert_equal "2024-11-05", json["result"]["protocolVersion"]
    assert_equal "evald-mcp-server", json["result"]["serverInfo"]["name"]
    assert json["result"]["capabilities"].key?("tools")
  end

  # ============================================
  # tools/list
  # ============================================

  test "tools/list returns all available tools" do
    post_mcp({ jsonrpc: "2.0", id: 2, method: "tools/list" })

    json = JSON.parse(response.body)
    tools = json["result"]["tools"]
    tool_names = tools.map { |t| t["name"] }

    assert_includes tool_names, "get_agent_score"
    assert_includes tool_names, "compare_agents"
    assert_includes tool_names, "get_agent_profile"
    assert_includes tool_names, "check_trust_threshold"
    assert_includes tool_names, "search_agents"
    assert_includes tool_names, "report_interaction"
    assert_equal 6, tools.size
  end

  test "tools have proper descriptions and schemas" do
    post_mcp({ jsonrpc: "2.0", id: 2, method: "tools/list" })

    json = JSON.parse(response.body)
    tools = json["result"]["tools"]

    tools.each do |tool|
      assert tool["name"].present?, "Tool should have a name"
      assert tool["description"].present?, "Tool #{tool['name']} should have a description"
      assert tool["inputSchema"].present?, "Tool #{tool['name']} should have an input schema"
      assert_equal "object", tool["inputSchema"]["type"]
    end
  end

  # ============================================
  # tools/call - get_agent_score
  # ============================================

  test "get_agent_score returns score data for valid agent" do
    post_mcp_tool("get_agent_score", { agent_id: "alpha-agent" })

    result = parse_tool_result
    assert_equal "alpha-agent", result["agent_id"]
    assert_equal "Alpha Agent", result["name"]
    assert result.key?("score")
    assert result.key?("confidence")
    assert result.key?("tier0")
    assert result.key?("tier1")
    assert result.key?("decay_status")
  end

  test "get_agent_score by name" do
    post_mcp_tool("get_agent_score", { agent_name: "Alpha Agent" })

    result = parse_tool_result
    assert_equal "alpha-agent", result["agent_id"]
  end

  test "get_agent_score returns error for unknown agent" do
    post_mcp_tool("get_agent_score", { agent_id: "nonexistent" })

    json = JSON.parse(response.body)
    content = json["result"]["content"].first
    assert content["isError"]
    assert_match(/not found/i, JSON.parse(content["text"])["error"])
  end

  # ============================================
  # tools/call - compare_agents
  # ============================================

  test "compare_agents returns comparison data" do
    post_mcp_tool("compare_agents", { agents: ["alpha-agent", "beta-agent"] })

    result = parse_tool_result
    assert_equal 2, result["agents"].size
    assert result.key?("recommendation")
    assert_equal "beta-agent", result["recommendation"]["recommended"]
  end

  test "compare_agents with task domain" do
    post_mcp_tool("compare_agents", { agents: ["alpha-agent", "beta-agent"], task_domain: "coding" })

    result = parse_tool_result
    assert_equal "coding", result["task_domain"]
  end

  test "compare_agents requires at least two agents" do
    post_mcp_tool("compare_agents", { agents: ["alpha-agent"] })

    json = JSON.parse(response.body)
    content = json["result"]["content"].first
    assert content["isError"]
  end

  test "compare_agents errors when fewer than two agents found" do
    post_mcp_tool("compare_agents", { agents: ["alpha-agent", "nonexistent-agent"] })

    json = JSON.parse(response.body)
    content = json["result"]["content"].first
    assert content["isError"]
    assert_match(/missing agents/i, JSON.parse(content["text"])["error"])
  end

  # ============================================
  # tools/call - get_agent_profile
  # ============================================

  test "get_agent_profile returns full profile data" do
    post_mcp_tool("get_agent_profile", { agent_id: "alpha-agent" })

    result = parse_tool_result
    assert_equal "alpha-agent", result["agent_id"]
    assert_equal "Alpha Agent", result["name"]
    assert result.key?("description")
    assert result.key?("builder")
    assert result.key?("tier")
    assert result.key?("safety_level")
    assert result.key?("claim_status")
    assert result.key?("interaction_count")
  end

  test "get_agent_profile returns error for unknown agent" do
    post_mcp_tool("get_agent_profile", { agent_id: "nonexistent" })

    json = JSON.parse(response.body)
    content = json["result"]["content"].first
    assert content["isError"]
  end

  # ============================================
  # tools/call - check_trust_threshold
  # ============================================

  test "check_trust_threshold passes when score meets threshold" do
    post_mcp_tool("check_trust_threshold", { agent_id: "beta-agent", minimum_score: 80 })

    result = parse_tool_result
    assert result["passes"]
    assert_equal "beta-agent", result["agent_id"]
    assert result["current_score"] >= 80
    assert_nil result["missing_requirements"]
  end

  test "check_trust_threshold fails when score below threshold" do
    post_mcp_tool("check_trust_threshold", { agent_id: "gamma-agent", minimum_score: 80 })

    result = parse_tool_result
    assert_not result["passes"]
    assert result["missing_requirements"].any? { |r| r.include?("score_below_threshold") }
  end

  test "check_trust_threshold checks required tiers" do
    post_mcp_tool("check_trust_threshold", { agent_id: "alpha-agent", minimum_score: 50, required_tiers: ["tier1"] })

    result = parse_tool_result
    assert_equal "alpha-agent", result["agent_id"]
    # Agent doesn't have tier1 data by default
    assert result["missing_requirements"]&.any? { |r| r.include?("tier1_data_missing") }
  end

  # ============================================
  # tools/call - search_agents
  # ============================================

  test "search_agents returns matching agents" do
    post_mcp_tool("search_agents", { capability: "coding" })

    result = parse_tool_result
    assert_equal 2, result["count"]
    result["agents"].each do |agent|
      assert agent.key?("agent_id")
      assert agent.key?("score")
    end
  end

  test "search_agents filters by minimum score" do
    post_mcp_tool("search_agents", { min_score: 80 })

    result = parse_tool_result
    result["agents"].each do |agent|
      assert agent["score"] >= 80
    end
  end

  test "search_agents respects limit" do
    post_mcp_tool("search_agents", { limit: 1 })

    result = parse_tool_result
    assert_equal 1, result["agents"].size
  end

  test "search_agents verified_only filter" do
    @agent1.update!(claim_status: "verified")
    post_mcp_tool("search_agents", { verified_only: true })

    result = parse_tool_result
    result["agents"].each do |agent|
      assert agent["verified"]
    end
  end

  # ============================================
  # tools/call - report_interaction
  # ============================================

  test "report_interaction creates an interaction record" do
    assert_difference "AgentInteraction.count", 1 do
      post_mcp_tool("report_interaction", {
        reporter_agent_id: "alpha-agent",
        target_agent_id: "beta-agent",
        interaction_type: "delegation",
        outcome: "Task completed successfully",
        success: true,
        notes: "Good collaboration"
      })
    end

    result = parse_tool_result
    assert result["recorded"]
    assert_equal "alpha-agent", result["reporter"]
    assert_equal "beta-agent", result["target"]
    assert result["total_interactions"] >= 1
  end

  test "report_interaction returns error for unknown reporter" do
    post_mcp_tool("report_interaction", {
      reporter_agent_id: "nonexistent",
      target_agent_id: "beta-agent",
      interaction_type: "delegation",
      outcome: "test",
      success: true
    })

    json = JSON.parse(response.body)
    content = json["result"]["content"].first
    assert content["isError"]
  end

  test "report_interaction returns error for unknown target" do
    post_mcp_tool("report_interaction", {
      reporter_agent_id: "alpha-agent",
      target_agent_id: "nonexistent",
      interaction_type: "delegation",
      outcome: "test",
      success: true
    })

    json = JSON.parse(response.body)
    content = json["result"]["content"].first
    assert content["isError"]
  end

  # ============================================
  # Batch requests
  # ============================================

  test "handles batch JSON-RPC requests" do
    post api_v1_mcp_url,
         params: [
           { jsonrpc: "2.0", id: 1, method: "ping" },
           { jsonrpc: "2.0", id: 2, method: "tools/list" }
         ].to_json,
         headers: auth_headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_kind_of Array, json
    assert_equal 2, json.size
  end

  private

  def auth_headers
    { "CONTENT_TYPE" => "application/json", "Authorization" => "Bearer #{@api_key.token}" }
  end

  def post_mcp(body)
    post api_v1_mcp_url,
         params: body.to_json,
         headers: auth_headers
  end

  def post_mcp_tool(tool_name, arguments)
    post_mcp({
      jsonrpc: "2.0",
      id: 1,
      method: "tools/call",
      params: { name: tool_name, arguments: arguments }
    })
  end

  def parse_tool_result
    json = JSON.parse(response.body)
    content = json["result"]["content"].first
    JSON.parse(content["text"])
  end
end
