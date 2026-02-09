module Tier0
  class DependencyRiskAnalyzer
    PACKAGE_FILES = %w[package.json Gemfile requirements.txt go.mod Cargo.toml].freeze

    def initialize(agent)
      @agent = agent
      @client = GithubClient.new
      parse_repo_url
    end

    def analyze
      {
        has_lockfile: check_lockfile,
        dependency_count: count_dependencies,
        security_alerts: fetch_security_alerts,
        score: calculate_score
      }
    end

    private

    def check_lockfile
      lockfiles = %w[package-lock.json yarn.lock Gemfile.lock go.sum Cargo.lock]
      lockfiles.any? { |f| @client.contents(@owner, @repo, f).present? }
    end

    def count_dependencies
      PACKAGE_FILES.sum do |file|
        content = @client.contents(@owner, @repo, file)
        next 0 unless content
        estimate_dep_count(file, content)
      end
    end

    def estimate_dep_count(file, content)
      return 0 unless content["content"]
      decoded = Base64.decode64(content["content"])

      case file
      when "package.json"
        json = JSON.parse(decoded) rescue {}
        (json["dependencies"]&.count || 0) + (json["devDependencies"]&.count || 0)
      when "Gemfile"
        decoded.scan(/^\s*gem\s+/).count
      when "requirements.txt"
        decoded.lines.count { |l| l.strip.present? && !l.start_with?("#") }
      else
        0
      end
    end

    def fetch_security_alerts
      alerts = @client.dependabot_alerts(@owner, @repo)
      return 0 unless alerts.is_a?(Array)
      alerts.count { |a| a["state"] == "open" }
    end

    def calculate_score
      alerts = fetch_security_alerts
      has_lock = check_lockfile

      base = 100
      base -= alerts * 15  # -15 per open alert
      base -= 20 unless has_lock  # -20 for no lockfile
      [base, 0].max
    end

    def parse_repo_url
      match = @agent.repo_url.match(%r{github\.com/([^/]+)/([^/]+)})
      @owner, @repo = match[1], match[2].sub(/\.git$/, "") if match
    end
  end
end
