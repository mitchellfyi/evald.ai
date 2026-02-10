# frozen_string_literal: true

module Tier0
  # Analyzes maintenance health based on commit recency, release cadence, and issue response time
  class MaintenancePulseAnalyzer
    COMMIT_THRESHOLDS = { active: 7, moderate: 30, stale: 90 }.freeze
    ISSUE_RESPONSE_THRESHOLDS = { fast: 48, moderate: 168, slow: 720 }.freeze

    def initialize(agent)
      @agent = agent
      @client = GithubClient.new
      @cache = Rails.cache
      parse_repo_url
    end

    def analyze
      return default_result unless @owner && @repo
      repo_info = fetch_repo_info
      return default_result unless repo_info

      commit_analysis = analyze_commit_recency(repo_info)
      release_analysis = analyze_release_cadence
      issue_analysis = analyze_issue_response_time

      {
        days_since_last_commit: commit_analysis[:days_since_last_commit],
        commit_recency_score: commit_analysis[:score],
        release_count_last_year: release_analysis[:count_last_year],
        avg_release_interval_days: release_analysis[:avg_interval_days],
        release_cadence_score: release_analysis[:score],
        median_issue_response_hours: issue_analysis[:median_response_hours],
        issue_response_score: issue_analysis[:score],
        issues_analyzed: issue_analysis[:issues_analyzed],
        score: calculate_overall_score(commit_analysis, release_analysis, issue_analysis)
      }
    rescue GithubClient::RateLimitError => e
      Rails.logger.warn("Rate limited while analyzing maintenance pulse: #{e.message}")
      default_result.merge(error: "rate_limited")
    rescue StandardError => e
      Rails.logger.error("Error analyzing maintenance pulse: #{e.message}")
      default_result.merge(error: e.message)
    end

    private

    def default_result
      {
        days_since_last_commit: nil, commit_recency_score: 0, release_count_last_year: 0,
        avg_release_interval_days: nil, release_cadence_score: 0, median_issue_response_hours: nil,
        issue_response_score: 0, issues_analyzed: 0, score: 0
      }
    end

    def fetch_repo_info
      info = @cache.fetch("github_repo:#{@owner}/#{@repo}", expires_in: 1.hour) { @client.repo(@owner, @repo) }
      # Return nil if this is an error response (e.g., 404)
      info && info["name"] ? info : nil
    end

    def analyze_commit_recency(repo_info)
      pushed_at = repo_info["pushed_at"]
      return { days_since_last_commit: nil, score: 0 } unless pushed_at
      days_since = ((Time.current - Time.parse(pushed_at)) / 1.day).round
      { days_since_last_commit: days_since, score: calculate_commit_recency_score(days_since) }
    rescue ArgumentError
      { days_since_last_commit: nil, score: 0 }
    end

    def calculate_commit_recency_score(days)
      case days
      when 0..7 then 50
      when 8..30 then 50 - ((days - 7).to_f / 23 * 20).round
      when 31..90 then 30 - ((days - 30).to_f / 60 * 20).round
      else [10 - ((days - 90) / 30), 0].max
      end
    end

    def analyze_release_cadence
      releases = fetch_releases
      return { count_last_year: 0, avg_interval_days: nil, score: 0 } if releases.empty?
      recent = releases.select { |r| Time.parse(r["published_at"] || r["created_at"]) > 1.year.ago rescue false }
      count = recent.size
      avg = calculate_average_release_interval(recent)
      { count_last_year: count, avg_interval_days: avg, score: calculate_release_cadence_score(count) }
    rescue ArgumentError
      { count_last_year: 0, avg_interval_days: nil, score: 0 }
    end

    def fetch_releases
      @cache.fetch("github_releases:#{@owner}/#{@repo}", expires_in: 6.hours) do
        uri = URI("https://api.github.com/repos/#{@owner}/#{@repo}/releases?per_page=100")
        request = Net::HTTP::Get.new(uri)
        token = Rails.application.credentials.dig(:github, :token) || ENV["GITHUB_TOKEN"]
        request["Authorization"] = "Bearer #{token}" if token
        request["Accept"] = "application/vnd.github.v3+json"
        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
        response.code.to_i == 200 ? JSON.parse(response.body) : []
      end
    rescue StandardError
      []
    end

    def calculate_average_release_interval(releases)
      return nil if releases.size < 2
      dates = releases.map { |r| Time.parse(r["published_at"] || r["created_at"]) }.sort.reverse
      intervals = dates.each_cons(2).map { |newer, older| (newer - older) / 1.day }
      (intervals.sum / intervals.size).round rescue nil
    end

    def calculate_release_cadence_score(count)
      case count
      when 12.. then 25
      when 4..11 then 15 + ((count - 4).to_f / 8 * 10).round
      when 1..3 then 5 + ((count - 1).to_f / 2 * 10).round
      else 0
      end
    end

    def analyze_issue_response_time
      issues = fetch_issues_with_comments
      return { median_response_hours: nil, score: 0, issues_analyzed: 0 } if issues.empty?
      times = calculate_response_times(issues)
      return { median_response_hours: nil, score: 0, issues_analyzed: 0 } if times.empty?
      median = calculate_median(times)
      { median_response_hours: median.round, score: calculate_issue_response_score(median), issues_analyzed: times.size }
    end

    def fetch_issues_with_comments
      @cache.fetch("github_issues:#{@owner}/#{@repo}", expires_in: 6.hours) { @client.issues(@owner, @repo, state: "all") }
    rescue StandardError
      []
    end

    def calculate_response_times(issues)
      issues.select { |i| !i.key?("pull_request") && (i["comments"] || 0) > 0 }.first(50).filter_map do |issue|
        created, updated = issue["created_at"], issue["updated_at"]
        next unless created && updated
        hours = (Time.parse(updated) - Time.parse(created)) / 1.hour rescue nil
        hours if hours && hours > 0 && hours < 8760
      end
    end

    def calculate_median(values)
      return 0 if values.empty?
      sorted = values.sort
      mid = sorted.size / 2
      sorted.size.odd? ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2.0
    end

    def calculate_issue_response_score(median)
      case median
      when 0..48 then 25
      when 49..168 then 24 - ((median - 48).to_f / 120 * 9).round
      when 169..720 then 14 - ((median - 168).to_f / 552 * 9).round
      else [5 - ((median - 720) / 720).round, 0].max
      end
    end

    def calculate_overall_score(commit, release, issue)
      (commit[:score] + release[:score] + issue[:score]).clamp(0, 100)
    end

    def parse_repo_url
      return unless @agent.repo_url
      match = @agent.repo_url.match(%r{github\.com/([^/]+)/([^/]+)})
      @owner, @repo = match[1], match[2].sub(/\.git$/, "") if match
    end
  end
end
