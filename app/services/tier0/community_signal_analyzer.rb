# frozen_string_literal: true

module Tier0
  # Analyzes community signals (stars, forks) with bot filtering and quality weighting
  # Addresses gaming of GitHub stars by evaluating account quality
  class CommunitySignalAnalyzer
    # Thresholds for sampling strategy
    FULL_SCAN_THRESHOLD = 500
    SAMPLE_SIZE = 200

    # Quality weights for account attributes
    ACCOUNT_AGE_WEIGHT = 0.25
    REPOS_WEIGHT = 0.20
    FOLLOWERS_WEIGHT = 0.20
    ACTIVITY_WEIGHT = 0.35

    # Minimum account age (days) to be considered legitimate
    MIN_ACCOUNT_AGE_DAYS = 30

    # Suspicious pattern thresholds
    BOT_RATIO_THRESHOLD = 0.3 # 30%+ low-quality stars is suspicious
    BURST_THRESHOLD = 0.5 # 50%+ stars in a single week is suspicious

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

      raw_stars = repo_info["stargazers_count"] || 0
      raw_forks = repo_info["forks_count"] || 0

      stargazer_analysis = analyze_stargazers(raw_stars)
      fork_analysis = analyze_forks(raw_forks)
      suspicious_patterns = detect_suspicious_patterns(stargazer_analysis, fork_analysis)

      {
        raw_stars: raw_stars,
        raw_forks: raw_forks,
        quality_stars: stargazer_analysis[:quality_weighted_count],
        quality_forks: fork_analysis[:quality_weighted_count],
        star_quality_ratio: stargazer_analysis[:quality_ratio],
        fork_quality_ratio: fork_analysis[:quality_ratio],
        sample_size: stargazer_analysis[:sample_size],
        bot_accounts_detected: stargazer_analysis[:low_quality_count],
        suspicious_patterns: suspicious_patterns,
        flags: generate_flags(suspicious_patterns),
        score: calculate_score(stargazer_analysis, fork_analysis, suspicious_patterns)
      }
    rescue GithubClient::RateLimitError => e
      Rails.logger.warn("Rate limited while analyzing community signals for #{@owner}/#{@repo}: #{e.message}")
      default_result.merge(error: "rate_limited")
    rescue StandardError => e
      Rails.logger.error("Error analyzing community signals for #{@owner}/#{@repo}: #{e.message}")
      default_result.merge(error: e.message)
    end

    private

    def default_result
      {
        raw_stars: 0,
        raw_forks: 0,
        quality_stars: 0,
        quality_forks: 0,
        star_quality_ratio: 0.0,
        fork_quality_ratio: 0.0,
        sample_size: 0,
        bot_accounts_detected: 0,
        suspicious_patterns: [],
        flags: [],
        score: 0
      }
    end

    def fetch_repo_info
      cache_key = "github_repo:#{@owner}/#{@repo}"
      @cache.fetch(cache_key, expires_in: 1.hour) do
        @client.repo(@owner, @repo)
      end
    end

    def analyze_stargazers(total_stars)
      return { quality_weighted_count: 0, quality_ratio: 0.0, sample_size: 0, low_quality_count: 0, timestamps: [] } if total_stars.zero?

      stargazers = fetch_stargazer_sample(total_stars)
      return { quality_weighted_count: 0, quality_ratio: 0.0, sample_size: 0, low_quality_count: 0, timestamps: [] } if stargazers.empty?

      quality_scores = score_accounts(stargazers.map { |s| s["user"] })
      timestamps = stargazers.map { |s| s["starred_at"] }.compact

      quality_weighted_count = quality_scores.sum
      sample_size = quality_scores.size
      low_quality_count = quality_scores.count { |s| s < 0.3 }

      # Extrapolate to full count if sampled
      if total_stars > FULL_SCAN_THRESHOLD && sample_size.positive?
        quality_ratio = quality_weighted_count / sample_size.to_f
        quality_weighted_count = (total_stars * quality_ratio).round
      end

      {
        quality_weighted_count: quality_weighted_count.round,
        quality_ratio: sample_size.positive? ? (quality_scores.sum / sample_size.to_f).round(2) : 0.0,
        sample_size: sample_size,
        low_quality_count: low_quality_count,
        timestamps: timestamps
      }
    end

    def analyze_forks(total_forks)
      return { quality_weighted_count: 0, quality_ratio: 0.0, sample_size: 0, low_quality_count: 0 } if total_forks.zero?

      forks = fetch_fork_sample(total_forks)
      return { quality_weighted_count: 0, quality_ratio: 0.0, sample_size: 0, low_quality_count: 0 } if forks.empty?

      # Extract owner info from forks
      owners = forks.map { |f| f["owner"] }.compact
      quality_scores = score_accounts(owners)

      quality_weighted_count = quality_scores.sum
      sample_size = quality_scores.size
      low_quality_count = quality_scores.count { |s| s < 0.3 }

      # Extrapolate to full count if sampled
      if total_forks > FULL_SCAN_THRESHOLD && sample_size.positive?
        quality_ratio = quality_weighted_count / sample_size.to_f
        quality_weighted_count = (total_forks * quality_ratio).round
      end

      {
        quality_weighted_count: quality_weighted_count.round,
        quality_ratio: sample_size.positive? ? (quality_scores.sum / sample_size.to_f).round(2) : 0.0,
        sample_size: sample_size,
        low_quality_count: low_quality_count
      }
    end

    def fetch_stargazer_sample(total_stars)
      cache_key = "stargazers:#{@owner}/#{@repo}"
      @cache.fetch(cache_key, expires_in: 24.hours) do
        if total_stars <= FULL_SCAN_THRESHOLD
          fetch_all_stargazers
        else
          fetch_random_stargazer_sample
        end
      end
    end

    def fetch_all_stargazers
      all_stargazers = []
      page = 1

      loop do
        batch = @client.stargazers(@owner, @repo, per_page: 100, page: page)
        break if batch.empty? || !batch.is_a?(Array)

        all_stargazers.concat(batch)
        break if batch.size < 100

        page += 1
        break if page > 10 # Safety limit
      end

      all_stargazers
    end

    def fetch_random_stargazer_sample
      # For large repos, fetch from different pages to get a representative sample
      sample = []
      pages_to_fetch = [1, 2, 5, 10, 20] # First, recent, and some middle pages

      pages_to_fetch.each do |page|
        batch = @client.stargazers(@owner, @repo, per_page: 40, page: page)
        break unless batch.is_a?(Array)

        sample.concat(batch)
        break if sample.size >= SAMPLE_SIZE
      end

      sample.take(SAMPLE_SIZE)
    end

    def fetch_fork_sample(total_forks)
      cache_key = "forks:#{@owner}/#{@repo}"
      @cache.fetch(cache_key, expires_in: 24.hours) do
        if total_forks <= FULL_SCAN_THRESHOLD
          fetch_all_forks
        else
          fetch_random_fork_sample
        end
      end
    end

    def fetch_all_forks
      all_forks = []
      page = 1

      loop do
        batch = @client.forks(@owner, @repo, per_page: 100, page: page)
        break if batch.empty? || !batch.is_a?(Array)

        all_forks.concat(batch)
        break if batch.size < 100

        page += 1
        break if page > 10 # Safety limit
      end

      all_forks
    end

    def fetch_random_fork_sample
      sample = []
      pages_to_fetch = [1, 2, 5, 10, 20]

      pages_to_fetch.each do |page|
        batch = @client.forks(@owner, @repo, per_page: 40, page: page)
        break unless batch.is_a?(Array)

        sample.concat(batch)
        break if sample.size >= SAMPLE_SIZE
      end

      sample.take(SAMPLE_SIZE)
    end

    def score_accounts(accounts)
      accounts.map { |account| score_single_account(account) }
    end

    def score_single_account(account)
      return 0.0 unless account.is_a?(Hash)

      # Use cached user details if available, otherwise use basic info
      user_details = fetch_user_details(account["login"])
      user = user_details || account

      age_score = calculate_age_score(user)
      repos_score = calculate_repos_score(user)
      followers_score = calculate_followers_score(user)
      activity_score = calculate_activity_score(user)

      weighted_score = (age_score * ACCOUNT_AGE_WEIGHT) +
                       (repos_score * REPOS_WEIGHT) +
                       (followers_score * FOLLOWERS_WEIGHT) +
                       (activity_score * ACTIVITY_WEIGHT)

      weighted_score.clamp(0.0, 1.0)
    end

    def fetch_user_details(username)
      return nil unless username

      cache_key = "github_user:#{username}"
      @cache.fetch(cache_key, expires_in: 24.hours) do
        @client.user(username)
      end
    end

    def calculate_age_score(user)
      created_at = user["created_at"]
      return 0.0 unless created_at

      account_age_days = (Time.current - Time.parse(created_at)) / 1.day

      return 0.0 if account_age_days < MIN_ACCOUNT_AGE_DAYS

      case account_age_days
      when 0...30 then 0.0
      when 30...90 then 0.3
      when 90...365 then 0.6
      when 365...730 then 0.8
      else 1.0
      end
    rescue ArgumentError
      0.0
    end

    def calculate_repos_score(user)
      repos = user["public_repos"] || 0

      case repos
      when 0 then 0.0
      when 1..2 then 0.2
      when 3..5 then 0.4
      when 6..10 then 0.6
      when 11..25 then 0.8
      else 1.0
      end
    end

    def calculate_followers_score(user)
      followers = user["followers"] || 0

      case followers
      when 0 then 0.1
      when 1..5 then 0.3
      when 6..20 then 0.5
      when 21..100 then 0.7
      when 101..500 then 0.9
      else 1.0
      end
    end

    def calculate_activity_score(user)
      # Check for recent activity using updated_at as a proxy
      # (Full activity check would require additional API calls)
      updated_at = user["updated_at"]
      return 0.3 unless updated_at # Default to moderate if unknown

      days_since_update = (Time.current - Time.parse(updated_at)) / 1.day

      case days_since_update
      when 0...30 then 1.0
      when 30...90 then 0.8
      when 90...180 then 0.6
      when 180...365 then 0.4
      else 0.2
      end
    rescue ArgumentError
      0.3
    end

    def detect_suspicious_patterns(stargazer_analysis, fork_analysis)
      patterns = []

      # High ratio of low-quality accounts
      if stargazer_analysis[:sample_size].positive?
        bot_ratio = stargazer_analysis[:low_quality_count].to_f / stargazer_analysis[:sample_size]
        patterns << "high_bot_ratio" if bot_ratio > BOT_RATIO_THRESHOLD
      end

      # Star burst detection (many stars in short time period)
      if stargazer_analysis[:timestamps].size >= 10
        patterns << "star_burst" if star_burst?(stargazer_analysis[:timestamps])
      end

      # Very low quality ratio
      patterns << "low_quality_stars" if stargazer_analysis[:quality_ratio] < 0.3

      # Suspicious fork patterns
      patterns << "low_quality_forks" if fork_analysis[:quality_ratio] < 0.3

      patterns
    end

    def star_burst?(timestamps)
      return false if timestamps.size < 10

      # Parse and sort timestamps
      dates = timestamps.map { |t| Time.parse(t).to_date rescue nil }.compact.sort

      return false if dates.size < 10

      # Check for concentration of stars in any 7-day window
      dates.each_cons(dates.size / 2) do |window|
        next if window.size < 5

        window_span_days = (window.last - window.first).to_i
        next if window_span_days.zero?

        # If half the sampled stars happened within a week, suspicious
        if window_span_days <= 7 && window.size >= (dates.size * BURST_THRESHOLD)
          return true
        end
      end

      false
    end

    def generate_flags(suspicious_patterns)
      flags = []

      flags << { type: "warning", message: "High ratio of bot/empty accounts detected" } if suspicious_patterns.include?("high_bot_ratio")
      flags << { type: "warning", message: "Unusual star burst detected - possible purchased stars" } if suspicious_patterns.include?("star_burst")
      flags << { type: "info", message: "Low overall star quality" } if suspicious_patterns.include?("low_quality_stars")
      flags << { type: "info", message: "Low overall fork quality" } if suspicious_patterns.include?("low_quality_forks")

      flags
    end

    def calculate_score(stargazer_analysis, fork_analysis, suspicious_patterns)
      # Base score from quality-weighted community metrics
      star_score = calculate_star_component(stargazer_analysis)
      fork_score = calculate_fork_component(fork_analysis)

      # Combine (stars weighted higher than forks)
      base_score = (star_score * 0.7) + (fork_score * 0.3)

      # Apply penalties for suspicious patterns
      penalty = suspicious_patterns.size * 10
      penalty = [penalty, 40].min # Cap penalty at 40 points

      final_score = base_score - penalty
      final_score.clamp(0, 100).round
    end

    def calculate_star_component(analysis)
      quality_stars = analysis[:quality_weighted_count]
      quality_ratio = analysis[:quality_ratio]

      # Score based on quality-weighted star count
      count_score = case quality_stars
                    when 0...10 then 10
                    when 10...50 then 30
                    when 50...200 then 50
                    when 200...1000 then 70
                    when 1000...5000 then 85
                    else 100
                    end

      # Adjust by quality ratio (bonus for high quality, penalty for low)
      quality_multiplier = 0.7 + (quality_ratio * 0.6) # Range: 0.7 to 1.3

      (count_score * quality_multiplier).clamp(0, 100)
    end

    def calculate_fork_component(analysis)
      quality_forks = analysis[:quality_weighted_count]
      quality_ratio = analysis[:quality_ratio]

      count_score = case quality_forks
                    when 0...5 then 10
                    when 5...20 then 30
                    when 20...100 then 50
                    when 100...500 then 70
                    when 500...2000 then 85
                    else 100
                    end

      quality_multiplier = 0.7 + (quality_ratio * 0.6)

      (count_score * quality_multiplier).clamp(0, 100)
    end

    def parse_repo_url
      return unless @agent.repo_url

      match = @agent.repo_url.match(%r{github\.com/([^/]+)/([^/]+)})
      @owner, @repo = match[1], match[2].sub(/\.git$/, "") if match
    end
  end
end
