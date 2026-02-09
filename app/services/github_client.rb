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
end
