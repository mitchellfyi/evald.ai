class GithubClient
  BASE_URL = "https://api.github.com"

  def initialize(token: ENV["GITHUB_TOKEN"])
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

  private

  def get(path, params = {})
    uri = URI("#{BASE_URL}#{path}")
    uri.query = URI.encode_www_form(params) if params.any?

    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{@token}" if @token
    request["Accept"] = "application/vnd.github.v3+json"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
    JSON.parse(response.body)
  end
end
