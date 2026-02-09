require "net/http"
require "json"
require "uri"

class GithubScraperJob < ApplicationJob
  queue_as :default

  SEARCH_TERMS = [
    "ai agent",
    "llm agent",
    "autonomous agent",
    "agentic",
    "mcp server"
  ].freeze

  # Respect GitHub rate limits
  RATE_LIMIT_DELAY = 2.seconds
  RESULTS_PER_PAGE = 100

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(search_term = nil)
    if search_term
      scrape_term(search_term)
    else
      # Queue individual jobs for each search term
      SEARCH_TERMS.each do |term|
        GithubScraperJob.perform_later(term)
        sleep(RATE_LIMIT_DELAY)
      end
    end
  end

  private

  def scrape_term(term)
    page = 1
    loop do
      response = fetch_repos(term, page)
      break if response["items"].blank?

      response["items"].each do |repo|
        upsert_agent(repo)
      end

      page += 1
      break if page > 5 # Max 500 per term
      sleep(RATE_LIMIT_DELAY)
    end
  end

  def fetch_repos(term, page)
    uri = URI("https://api.github.com/search/repositories")
    uri.query = URI.encode_www_form(
      q: "#{term} in:name,description,readme",
      sort: "stars",
      order: "desc",
      per_page: RESULTS_PER_PAGE,
      page: page
    )

    request = Net::HTTP::Get.new(uri)
    request["Accept"] = "application/vnd.github.v3+json"
    request["User-Agent"] = "evaled.ai-scraper"

    # Use GITHUB_TOKEN if available
    if ENV["GITHUB_TOKEN"].present?
      request["Authorization"] = "Bearer #{ENV['GITHUB_TOKEN']}"
    end

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    JSON.parse(response.body)
  end

  def upsert_agent(repo)
    Agent.find_or_initialize_by(github_id: repo["id"]).tap do |agent|
      agent.assign_attributes(
        name: repo["name"],
        description: repo["description"]&.truncate(500),
        repo_url: repo["html_url"],
        stars: repo["stargazers_count"],
        language: repo["language"],
        github_last_updated_at: repo["updated_at"],
        owner: repo.dig("owner", "login")
      )
      agent.save!
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn "Failed to save agent #{repo['name']}: #{e.message}"
  end
end
