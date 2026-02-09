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
    request["User-Agent"] = "evald.ai-seeder"
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
