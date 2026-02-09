# frozen_string_literal: true
class ClaimVerificationService
  def initialize(claim)
    @claim = claim
    @agent = claim.agent
  end

  def verify
    result = case @claim.verification_method
    when "dns_txt" then verify_dns
    when "github_file" then verify_github
    when "api_key" then verify_api_key?
    else false
    end

    result ? @claim.verify! : @claim
  end

  private

  def verify_dns
    domain = extract_domain(@agent.repo_url)
    return false unless domain

    expected_token = @claim.verification_data["token"]

    # Check DNS TXT record
    begin
      records = Resolv::DNS.open { |dns| dns.getresources("_evald.#{domain}", Resolv::DNS::Resource::IN::TXT) }
      records.any? { |r| r.strings.join.include?(expected_token) }
    rescue
      false
    end
  end

  def verify_github
    owner, repo = parse_github_url(@agent.repo_url)
    return false unless owner && repo

    expected_token = @claim.verification_data["token"]
    client = GithubClient.new

    begin
      content = client.contents(owner, repo, ".evald/verify.txt")
      return false unless content&.dig("content")

      decoded = Base64.decode64(content["content"])
      decoded.include?(expected_token)
    rescue
      false
    end
  end

  def verify_api_key?
    expected_key = @claim.verification_data["api_key"]
    return false unless expected_key

    # API key verification would call the agent's API
    true  # Placeholder
  end

  def extract_domain(url)
    URI.parse(url).host rescue nil
  end

  def parse_github_url(url)
    match = url.match(%r{github\.com/([^/]+)/([^/]+)})
    return nil unless match
    [match[1], match[2].sub(/\.git$/, "")]
  end
end
