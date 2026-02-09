# frozen_string_literal: true

class GithubTrendingService
  SEARCH_TERMS = [
    '"ai agent"',
    '"autonomous agent"',
    '"llm agent"',
    '"agentic framework"'
  ].freeze

  AGENT_TOPICS = %w[
    ai-agent ai-agents autonomous-agent autonomous-agents
    agent-framework multi-agent-systems llm-agent agentic
  ].freeze

  EXCLUDE_KEYWORDS = %w[mcp-server mcp-integration sdk-only].freeze

  MIN_STARS = 100
  RATE_LIMIT_DELAY = 2

  def initialize(github_client: GithubClient.new)
    @client = github_client
  end

  def discover
    candidates = search_recent_repos
    candidates.filter_map do |repo|
      next if already_tracked?(repo)
      next if excluded?(repo)

      score = calculate_confidence(repo)
      next if score < 50

      create_pending_agent(repo, score)
    end
  end

  def calculate_confidence(repo)
    score = 0
    score += keyword_score(repo)
    score += topic_score(repo)
    score += stars_score(repo)
    score += activity_score(repo)
    score += documentation_score(repo)
    score += license_score(repo)
    score += examples_score(repo)
    [score, 100].min
  end

  private

  def search_recent_repos
    repos = []
    one_week_ago = 1.week.ago.strftime("%Y-%m-%d")

    SEARCH_TERMS.each do |term|
      results = search_github(term, created_after: one_week_ago)
      repos.concat(results)
      sleep(RATE_LIMIT_DELAY)
    end

    repos.uniq { |r| r["id"] }
  end

  def search_github(term, created_after:)
    query = "#{term} in:name,description,readme created:>#{created_after} stars:>=#{MIN_STARS}"
    response = @client.search_repositories(query, sort: "stars", per_page: 30)
    response&.dig("items") || []
  rescue StandardError => e
    Rails.logger.error("GitHub search failed for '#{term}': #{e.message}")
    []
  end

  def already_tracked?(repo)
    url = repo["html_url"]
    Agent.exists?(repo_url: url) || PendingAgent.exists?(github_url: url)
  end

  def excluded?(repo)
    name = repo["name"]&.downcase || ""
    description = repo["description"]&.downcase || ""
    text = "#{name} #{description}"

    # Exclude MCP servers/integrations, pure SDKs, and forks
    return true if repo["fork"]
    return true if EXCLUDE_KEYWORDS.any? { |kw| text.include?(kw) }

    false
  end

  def keyword_score(repo)
    name = repo["name"]&.downcase || ""
    description = repo["description"]&.downcase || ""
    text = "#{name} #{description}"

    keywords = %w[agent autonomous agentic]
    keywords.any? { |kw| text.include?(kw) } ? 20 : 0
  end

  def topic_score(repo)
    topics = repo["topics"] || []
    (topics & AGENT_TOPICS).any? ? 15 : 0
  end

  def stars_score(repo)
    stars = repo["stargazers_count"] || 0
    stars >= 50 ? 15 : 0
  end

  def activity_score(repo)
    pushed_at = repo["pushed_at"]
    return 0 unless pushed_at

    last_push = Time.parse(pushed_at)
    last_push > 7.days.ago ? 15 : 0
  end

  def documentation_score(repo)
    description = repo["description"] || ""
    has_homepage = repo["homepage"].present?

    score = 0
    score += 10 if description.length > 50
    score += 5 if has_homepage
    [score, 15].min
  end

  def license_score(repo)
    repo.dig("license", "key").present? ? 10 : 0
  end

  def examples_score(repo)
    has_topics = (repo["topics"] || []).length > 2
    has_topics ? 10 : 0
  end

  def create_pending_agent(repo, score)
    PendingAgent.create!(
      name: repo["name"],
      github_url: repo["html_url"],
      description: repo["description"]&.truncate(500),
      owner: repo.dig("owner", "login"),
      stars: repo["stargazers_count"],
      language: repo["language"],
      license: repo.dig("license", "key"),
      topics: repo["topics"] || [],
      confidence_score: score,
      discovered_at: Time.current
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn("Failed to create pending agent #{repo['name']}: #{e.message}")
    nil
  end
end
