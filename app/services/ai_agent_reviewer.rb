# frozen_string_literal: true

# Service to classify and review pending agents using OpenAI
# Determines whether a GitHub repository is a genuine AI agent
class AiAgentReviewer
  CLASSIFICATIONS = %w[agent sdk library tool framework unknown].freeze
  CATEGORIES = %w[coding research automation browser data workflow assistant creative analytics security].freeze

  # Thresholds for auto-approval/rejection
  AUTO_APPROVE_THRESHOLD = 0.8
  AUTO_REJECT_THRESHOLD = 0.3

  def initialize(pending_agent, client: nil)
    @agent = pending_agent
    @client = client || build_openai_client
    @github_client = GithubClient.new
  end

  # Run AI review on the pending agent
  # @return [Hash] the review result with classification details
  def review
    return skip_result("Already reviewed") if @agent.ai_reviewed_at.present?

    readme = fetch_readme
    repo_info = fetch_repo_info

    return skip_result("Could not fetch repository data") if readme.blank? && repo_info.blank?

    response = call_openai(readme, repo_info)
    result = parse_response(response)

    update_agent(result)
    result
  rescue Faraday::Error, JSON::ParserError => e
    Rails.logger.error("AiAgentReviewer error for #{@agent.github_url}: #{e.message}")
    skip_result("API error: #{e.message}")
  end

  private

  def build_openai_client
    OpenAI::Client.new(access_token: Rails.application.credentials.dig(:openai, :api_key))
  end

  def fetch_readme
    owner, repo = parse_github_url
    @github_client.fetch_readme(owner, repo)
  rescue StandardError => e
    Rails.logger.warn("Failed to fetch README for #{@agent.github_url}: #{e.message}")
    nil
  end

  def fetch_repo_info
    owner, repo = parse_github_url
    @github_client.fetch_repository(owner, repo)
  rescue StandardError => e
    Rails.logger.warn("Failed to fetch repo info for #{@agent.github_url}: #{e.message}")
    nil
  end

  def parse_github_url
    # Extract owner/repo from https://github.com/owner/repo
    match = @agent.github_url.match(%r{github\.com/([^/]+)/([^/]+)})
    raise ArgumentError, "Invalid GitHub URL: #{@agent.github_url}" unless match

    [match[1], match[2]]
  end

  def call_openai(readme, repo_info)
    @client.chat(
      parameters: {
        model: openai_model,
        messages: build_messages(readme, repo_info),
        response_format: { type: "json_object" },
        temperature: 0.3,
        max_tokens: 1000
      }
    )
  end

  def openai_model
    Rails.application.credentials.dig(:openai, :model) || "gpt-4o"
  end

  def build_messages(readme, repo_info)
    [
      { role: "system", content: system_prompt },
      { role: "user", content: user_prompt(readme, repo_info) }
    ]
  end

  def system_prompt
    <<~PROMPT
      You are an AI agent classifier for Evald, an independent evaluation platform for AI agents.
      Your job is to determine whether a GitHub repository contains a genuine autonomous AI agent
      or something else (SDK, library, tool, framework, etc.).

      A genuine AI agent:
      - Can take autonomous actions on behalf of users
      - Makes decisions based on context/goals
      - Operates with some degree of independence
      - Is NOT just a library or SDK for building agents
      - Is NOT just an API wrapper or integration tool
      - Is NOT a framework for building agents (unless it also IS an agent)

      Classification types:
      - "agent": A genuine autonomous AI agent
      - "sdk": Software development kit for building agents
      - "library": Code library or package
      - "tool": Developer tool or utility
      - "framework": Framework for building agents or AI applications
      - "unknown": Cannot determine from available information

      Categories (for agents only):
      #{CATEGORIES.join(", ")}

      Respond with a JSON object containing:
      {
        "is_agent": boolean,
        "classification": "agent" | "sdk" | "library" | "tool" | "framework" | "unknown",
        "confidence": 0.0-1.0,
        "categories": ["category1", "category2"],
        "description": "A concise 1-2 sentence description of what this does",
        "capabilities": ["capability1", "capability2", ...],
        "reasoning": "Brief explanation of why you classified it this way"
      }

      Be conservative: when in doubt, classify as NOT an agent (is_agent: false).
      Only mark as agent if there's clear evidence of autonomous behavior.
    PROMPT
  end

  def user_prompt(readme, repo_info)
    parts = []

    if repo_info.present?
      parts << "Repository Information:"
      parts << "- Name: #{repo_info["name"]}"
      parts << "- Description: #{repo_info["description"]}" if repo_info["description"].present?
      parts << "- Language: #{repo_info["language"]}" if repo_info["language"].present?
      parts << "- Topics: #{repo_info["topics"]&.join(", ")}" if repo_info["topics"]&.any?
      parts << "- Stars: #{repo_info["stargazers_count"]}"
      parts << ""
    end

    if readme.present?
      # Truncate README to avoid token limits
      truncated_readme = readme[0, 8000]
      parts << "README Content:"
      parts << truncated_readme
      parts << "..." if readme.length > 8000
    else
      parts << "No README available."
    end

    parts.join("\n")
  end

  def parse_response(response)
    content = response.dig("choices", 0, "message", "content")
    raise JSON::ParserError, "Empty response from OpenAI" if content.blank?

    result = JSON.parse(content)
    validate_result(result)
    result
  end

  def validate_result(result)
    # Ensure required fields exist
    result["is_agent"] = result["is_agent"] == true
    result["classification"] = result["classification"]&.downcase || "unknown"
    result["confidence"] = (result["confidence"] || 0.0).to_f.clamp(0.0, 1.0)
    result["categories"] = Array(result["categories"]).select { |c| CATEGORIES.include?(c) }
    result["capabilities"] = Array(result["capabilities"])
    result["description"] ||= ""
    result["reasoning"] ||= ""
  end

  def update_agent(result)
    @agent.update!(
      ai_classification: result["classification"],
      ai_confidence: result["confidence"],
      ai_categories: result["categories"],
      ai_description: result["description"],
      ai_capabilities: result["capabilities"],
      ai_reasoning: result["reasoning"],
      ai_reviewed_at: Time.current,
      is_agent: result["is_agent"]
    )
  end

  def skip_result(reason)
    {
      "is_agent" => false,
      "classification" => "unknown",
      "confidence" => 0.0,
      "categories" => [],
      "description" => "",
      "capabilities" => [],
      "reasoning" => reason,
      "skipped" => true
    }
  end
end
