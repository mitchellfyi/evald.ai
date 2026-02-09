# frozen_string_literal: true
# Seed top 500 AI agents from GitHub
# This is idempotent - uses find_or_create_by with github_id

require "net/http"
require "json"

class GithubAgentSeeder
  SEARCH_QUERIES = [
    "ai agent language:python",
    "ai agent language:typescript",
    "ai agent language:javascript",
    "llm agent",
    "autonomous agent",
    "langchain agent",
    "autogpt",
    "gpt agent",
    "claude agent",
    "mcp server"
  ].freeze

  GITHUB_API = "https://api.github.com"
  PER_PAGE = 100
  TARGET_COUNT = 500
  RATE_LIMIT_DELAY = 2

  def initialize
    @token = Rails.application.credentials.dig(:github, :token) || ENV["GITHUB_TOKEN"]
    @seeded_ids = Set.new
  end

  def seed
    puts "Seeding top #{TARGET_COUNT} AI agents from GitHub..."

    SEARCH_QUERIES.each do |query|
      break if @seeded_ids.size >= TARGET_COUNT

      seed_query(query)
      sleep(RATE_LIMIT_DELAY) # Respect rate limits
    end

    puts "Seeded #{@seeded_ids.size} agents."
  end

  private

  def seed_query(query)
    pages_needed = ((TARGET_COUNT - @seeded_ids.size) / PER_PAGE.to_f).ceil
    pages_needed = [pages_needed, 5].min # GitHub limits to 1000 results (10 pages)

    (1..pages_needed).each do |page|
      break if @seeded_ids.size >= TARGET_COUNT

      repos = fetch_repos(query, page)
      break if repos.empty?

      repos.each do |repo|
        break if @seeded_ids.size >= TARGET_COUNT
        next if @seeded_ids.include?(repo["id"])

        upsert_agent(repo)
        @seeded_ids.add(repo["id"])
      end

      sleep(RATE_LIMIT_DELAY)
    end
  end

  def fetch_repos(query, page)
    uri = URI("#{GITHUB_API}/search/repositories")
    uri.query = URI.encode_www_form(
      q: query,
      sort: "stars",
      order: "desc",
      per_page: PER_PAGE,
      page: page
    )

    request = Net::HTTP::Get.new(uri)
    request["Accept"] = "application/vnd.github.v3+json"
    request["User-Agent"] = "evaled.ai-seeder"
    request["Authorization"] = "Bearer #{@token}" if @token.present?

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    if response.code.to_i == 200
      JSON.parse(response.body)["items"] || []
    else
      puts "GitHub API error: #{response.code} - #{response.body}"
      []
    end
  rescue => e
    puts "Error fetching repos: #{e.message}"
    []
  end

  def upsert_agent(repo)
    Agent.find_or_create_by!(github_id: repo["id"]) do |agent|
      agent.name = repo["name"]
      agent.description = repo["description"]&.truncate(500)
      agent.repo_url = repo["html_url"]
      agent.stars = repo["stargazers_count"]
      agent.language = repo["language"]
      agent.owner = repo.dig("owner", "login")
      agent.github_last_updated_at = repo["updated_at"]
    end
  rescue ActiveRecord::RecordInvalid => e
    puts "Skipping #{repo['name']}: #{e.message}"
  end
end

# Run the seeder
GithubAgentSeeder.new.seed

# Add specific high-value open-source AI agents
# These are manually curated agents that should be in the database
puts "\nSeeding manually curated agents..."

CURATED_AGENTS = [
  {
    name: "Skyvern",
    github_url: "https://github.com/skyvern-ai/skyvern",
    description: "Browser automation agent that navigates websites and completes tasks autonomously using LLMs and computer vision"
  },
  {
    name: "CUA",
    github_url: "https://github.com/trycua/cua",
    description: "Computer-Use Agent that runs workflows on Apple Silicon macOS with autonomous desktop control"
  },
  {
    name: "Deep Research",
    github_url: "https://github.com/ozamatash/deep-research-mcp",
    description: "Performs iterative deep research using search engines, web scraping, and LLMs to generate comprehensive reports"
  },
  {
    name: "ManusMCP",
    github_url: "https://github.com/mantrakp04/manusmcp",
    description: "Orchestrates specialized agents for collaborative task execution with file operations and browser automation"
  },
  {
    name: "DesktopCommander",
    github_url: "https://github.com/wonderwhy-er/DesktopCommanderMCP",
    description: "Executes terminal commands and edits files autonomously on your computer"
  },
  {
    name: "Inbox Zero",
    github_url: "https://github.com/elie222/inbox-zero",
    description: "AI personal assistant for autonomous email management, triage, and response"
  },
  {
    name: "Browserbase",
    github_url: "https://github.com/browserbase/mcp-server-browserbase",
    description: "Automates web browsers remotely in cloud environments for headless browser automation"
  },
  {
    name: "Activepieces",
    github_url: "https://github.com/activepieces/activepieces",
    description: "Open-source workflow automation platform with AI-powered flows and 200+ integrations"
  }
].freeze

CURATED_AGENTS.each do |agent_data|
  begin
    agent = Agent.find_by(repo_url: agent_data[:github_url])
    
    if agent
      puts "  ℹ #{agent_data[:name]} already exists"
    else
      agent = Agent.create!(
        name: agent_data[:name],
        description: agent_data[:description],
        repo_url: agent_data[:github_url],
        owner: agent_data[:github_url].match(%r{github\.com/([^/]+)/[^/]+(?:/|$)})[1]
      )
      puts "  ✓ Added #{agent_data[:name]}"
    end
  rescue ActiveRecord::RecordInvalid => e
    puts "  ⚠ Skipping #{agent_data[:name]}: #{e.message}"
  end
end

puts "Curated agents seeding complete."
