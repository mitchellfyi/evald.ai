# frozen_string_literal: true
class GithubClient
  BASE_URL = "https://api.github.com"

  def initialize(token: Rails.application.credentials.dig(:github, :token) || ENV["GITHUB_TOKEN"])
    @token = token
  end

  def repo(owner, name)
    get("/repos/#{owner}/#{name}")
  end

  def commits(owner, name, since: 6.months.ago)
    get("/repos/#{owner}/#{name}/commits", since: since.iso8601)
  end

  def issues(owner, name, state: "all")
    get("/repos/#{owner}/#{name}/issues", state: state)
  end

  def contributors(owner, name)
    get("/repos/#{owner}/#{name}/contributors")
  end

  def security_advisories(owner, name)
    get("/repos/#{owner}/#{name}/vulnerability-alerts") rescue []
  end

  def dependabot_alerts(owner, name)
    get("/repos/#{owner}/#{name}/dependabot/alerts") rescue []
  end

  def contents(owner, name, path)
    response = get_with_status("/repos/#{owner}/#{name}/contents/#{path}")
    return nil unless response[:status] == 200
    response[:body]
  rescue StandardError
    nil
  end

  # Fetch repository information
  def fetch_repository(owner, name)
    repo(owner, name)
  rescue StandardError
    nil
  end

  # Fetch and decode README content
  def fetch_readme(owner, name)
    response = get_with_status("/repos/#{owner}/#{name}/readme")
    return nil unless response[:status] == 200

    content = response[:body]["content"]
    encoding = response[:body]["encoding"]

    return nil unless content.present?

    case encoding
    when "base64"
      Base64.decode64(content)
    else
      content
    end
  rescue StandardError => e
    Rails.logger.warn("Failed to fetch README for #{owner}/#{name}: #{e.message}")
    nil
  end

  # Check user's permission level on a repository
  # Returns: { permission: "admin"|"maintain"|"write"|"triage"|"read", ... }
  # or nil if the user is not a collaborator
  def collaborator_permission(owner, name, username)
    return nil unless @token

    response = get_with_status("/repos/#{owner}/#{name}/collaborators/#{username}/permission")

    case response[:status]
    when 200
      response[:body]
    when 404
      # User is not a collaborator or repo doesn't exist
      nil
    when 403
      # Rate limited or forbidden
      raise RateLimitError, "GitHub API rate limit exceeded" if response[:body]["message"]&.include?("rate limit")
      nil
    else
      nil
    end
  end

  def search_repositories(query, sort: "stars", per_page: 30)
    get("/search/repositories", q: query, sort: sort, order: "desc", per_page: per_page)
  end

  # Fetch stargazers with timestamps (requires special Accept header)
  # Returns array of { user: {...}, starred_at: "ISO8601" }
  def stargazers(owner, name, per_page: 100, page: 1)
    get_with_header(
      "/repos/#{owner}/#{name}/stargazers",
      { per_page: per_page, page: page },
      "application/vnd.github.v3.star+json"
    )
  rescue RateLimitError
    raise # Re-raise rate limit errors for proper handling upstream
  rescue StandardError => e
    Rails.logger.warn("Failed to fetch stargazers for #{owner}/#{name}: #{e.message}")
    []
  end

  # Fetch forkers (users who forked the repo)
  def forks(owner, name, per_page: 100, page: 1)
    result = get("/repos/#{owner}/#{name}/forks", per_page: per_page, page: page, sort: "newest")
    # Handle error responses (API returns hash with "message" key on errors)
    return [] unless result.is_a?(Array)

    result
  rescue StandardError => e
    Rails.logger.warn("Failed to fetch forks for #{owner}/#{name}: #{e.message}")
    []
  end

  # Fetch user details for quality scoring
  def user(username)
    get("/users/#{username}")
  rescue StandardError => e
    Rails.logger.warn("Failed to fetch user #{username}: #{e.message}")
    nil
  end

  # Fetch user's recent activity (events)
  def user_events(username, per_page: 30)
    get("/users/#{username}/events/public", per_page: per_page)
  rescue StandardError => e
    Rails.logger.warn("Failed to fetch events for #{username}: #{e.message}")
    []
  end

  # Get rate limit status
  def rate_limit
    get("/rate_limit")
  rescue StandardError
    { "rate" => { "remaining" => 0 } }
  end

  class RateLimitError < StandardError; end
  class RepoNotFoundError < StandardError; end

  private

  def get(path, params = {})
    response = get_with_status(path, params)
    response[:body]
  end

  def get_with_status(path, params = {})
    uri = URI("#{BASE_URL}#{path}")
    uri.query = URI.encode_www_form(params) if params.any?

    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{@token}" if @token
    request["Accept"] = "application/vnd.github.v3+json"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }

    {
      status: response.code.to_i,
      body: JSON.parse(response.body)
    }
  rescue JSON::ParserError
    { status: response&.code.to_i, body: {} }
  end

  def get_with_header(path, params = {}, accept_header = "application/vnd.github.v3+json")
    uri = URI("#{BASE_URL}#{path}")
    uri.query = URI.encode_www_form(params) if params.any?

    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{@token}" if @token
    request["Accept"] = accept_header

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }

    raise RateLimitError, "GitHub API rate limit exceeded" if response.code.to_i == 403

    JSON.parse(response.body)
  rescue JSON::ParserError
    []
  end
end
