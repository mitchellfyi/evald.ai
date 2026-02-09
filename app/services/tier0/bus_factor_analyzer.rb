module Tier0
  class BusFactorAnalyzer
    def initialize(agent)
      @agent = agent
      @client = GithubClient.new
      parse_repo_url
    end

    def analyze
      contributors = fetch_contributors
      return { score: 0, active_contributors: 0 } if contributors.empty?

      {
        active_contributors: contributors.count,
        top_contributor_pct: calculate_top_contributor_pct(contributors),
        bus_factor: estimate_bus_factor(contributors),
        score: calculate_score(contributors)
      }
    end

    private

    def fetch_contributors
      @client.contributors(@owner, @repo).first(100) rescue []
    end

    def calculate_top_contributor_pct(contributors)
      return 100.0 if contributors.count == 1
      total = contributors.sum { |c| c["contributions"] }
      top = contributors.first["contributions"]
      (top.to_f / total * 100).round(1)
    end

    def estimate_bus_factor(contributors)
      # How many contributors make up 80% of commits?
      total = contributors.sum { |c| c["contributions"] }
      threshold = total * 0.8
      running = 0
      contributors.each_with_index do |c, i|
        running += c["contributions"]
        return i + 1 if running >= threshold
      end
      contributors.count
    end

    def calculate_score(contributors)
      count_score = case contributors.count
        when 5.. then 100
        when 3..4 then 70
        when 2 then 40
        else 20
      end

      # Penalty if top contributor > 80%
      top_pct = calculate_top_contributor_pct(contributors)
      penalty = top_pct > 80 ? 20 : 0

      [count_score - penalty, 0].max
    end

    def parse_repo_url
      match = @agent.repo_url.match(%r{github\.com/([^/]+)/([^/]+)})
      @owner, @repo = match[1], match[2].sub(/\.git$/, "") if match
    end
  end
end
