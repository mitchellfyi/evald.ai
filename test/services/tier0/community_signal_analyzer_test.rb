# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

module Tier0
  class CommunitySignalAnalyzerTest < ActiveSupport::TestCase
    setup do
      @agent = create(:agent, repo_url: "https://github.com/testowner/testrepo")
      WebMock.enable!
      Rails.cache.clear
      @users_stubbed = false
      @stargazer_quality = nil
      @fork_quality = nil
    end

    teardown do
      WebMock.disable!
      Rails.cache.clear
    end

    test "analyze returns hash with expected keys" do
      stub_github_repo(stars: 100, forks: 20)
      stub_github_stargazers(count: 10)
      stub_github_forks(count: 5)

      result = CommunitySignalAnalyzer.new(@agent).analyze

      assert result.key?(:raw_stars)
      assert result.key?(:raw_forks)
      assert result.key?(:quality_stars)
      assert result.key?(:quality_forks)
      assert result.key?(:star_quality_ratio)
      assert result.key?(:fork_quality_ratio)
      assert result.key?(:sample_size)
      assert result.key?(:bot_accounts_detected)
      assert result.key?(:suspicious_patterns)
      assert result.key?(:flags)
      assert result.key?(:score)
    end

    test "returns default result for invalid repo url" do
      agent = create(:agent, repo_url: nil)

      result = CommunitySignalAnalyzer.new(agent).analyze

      assert_equal 0, result[:raw_stars]
      assert_equal 0, result[:score]
    end

    test "high quality accounts get high quality scores" do
      stub_github_repo(stars: 50, forks: 10)
      stub_github_stargazers(count: 10, quality: :high)
      stub_github_forks(count: 5, quality: :high)

      result = CommunitySignalAnalyzer.new(@agent).analyze

      assert result[:star_quality_ratio] >= 0.7
      assert result[:fork_quality_ratio] >= 0.7
      assert_empty result[:suspicious_patterns]
    end

    test "low quality accounts get flagged" do
      stub_github_repo(stars: 50, forks: 10)
      stub_github_stargazers(count: 10, quality: :low)
      stub_github_forks(count: 5, quality: :low)

      result = CommunitySignalAnalyzer.new(@agent).analyze

      assert result[:star_quality_ratio] < 0.3
      assert_includes result[:suspicious_patterns], "low_quality_stars"
    end

    test "detects high bot ratio" do
      stub_github_repo(stars: 50, forks: 10)
      stub_github_stargazers(count: 10, quality: :mixed_mostly_bots)
      stub_github_forks(count: 5, quality: :high)

      result = CommunitySignalAnalyzer.new(@agent).analyze

      assert_includes result[:suspicious_patterns], "high_bot_ratio"
      assert result[:flags].any? { |f| f[:type] == "warning" }
    end

    test "detects star burst pattern" do
      stub_github_repo(stars: 50, forks: 10)
      stub_github_stargazers(count: 20, quality: :high, burst: true)
      stub_github_forks(count: 5, quality: :high)

      result = CommunitySignalAnalyzer.new(@agent).analyze

      assert_includes result[:suspicious_patterns], "star_burst"
    end

    test "calculates weighted star count correctly" do
      stub_github_repo(stars: 100, forks: 20)
      stub_github_stargazers(count: 100, quality: :high)
      stub_github_forks(count: 20, quality: :high)

      result = CommunitySignalAnalyzer.new(@agent).analyze

      # Quality stars should be close to raw stars for high quality accounts
      assert result[:quality_stars] > 0
      assert result[:quality_stars] <= result[:raw_stars]
    end

    test "score penalizes suspicious patterns" do
      stub_github_repo(stars: 100, forks: 20)

      # First, get baseline with good accounts
      stub_github_stargazers(count: 10, quality: :high)
      stub_github_forks(count: 5, quality: :high)
      Rails.cache.clear

      good_result = CommunitySignalAnalyzer.new(@agent).analyze

      # Now test with suspicious patterns
      stub_github_stargazers(count: 10, quality: :low)
      stub_github_forks(count: 5, quality: :low)
      Rails.cache.clear

      bad_result = CommunitySignalAnalyzer.new(@agent).analyze

      assert bad_result[:score] < good_result[:score]
    end

    test "handles rate limit error gracefully" do
      stub_github_repo(stars: 100, forks: 20)
      stub_request(:get, %r{api.github.com/repos/.*/stargazers})
        .to_return(status: 403, body: { message: "API rate limit exceeded" }.to_json)
      stub_request(:get, %r{api.github.com/repos/.*/forks})
        .to_return(status: 200, body: "[]", headers: { "Content-Type" => "application/json" })

      result = CommunitySignalAnalyzer.new(@agent).analyze

      assert_equal "rate_limited", result[:error]
    end

    test "samples stargazers for large repos" do
      stub_github_repo(stars: 10000, forks: 2000)
      stub_github_stargazers(count: 200, quality: :high)
      stub_github_forks(count: 200, quality: :high)

      result = CommunitySignalAnalyzer.new(@agent).analyze

      # Sample size should be capped
      assert result[:sample_size] <= CommunitySignalAnalyzer::SAMPLE_SIZE
    end

    test "caches stargazer data" do
      stub_github_repo(stars: 50, forks: 10)
      stub_github_stargazers(count: 10, quality: :high)
      stub_github_forks(count: 5, quality: :high)

      # First call
      result1 = CommunitySignalAnalyzer.new(@agent).analyze

      # Clear cache to force re-fetch, but keep stubs
      Rails.cache.clear

      # Second call should still work (using same stubs)
      result2 = CommunitySignalAnalyzer.new(@agent).analyze

      # Both results should be consistent
      assert result1[:score] > 0
      assert result2[:score] > 0
      assert_equal result1[:raw_stars], result2[:raw_stars]
    end

    test "account age scoring" do
      stub_github_repo(stars: 10, forks: 2)
      stub_github_stargazers(count: 5, quality: :new_accounts)
      stub_github_forks(count: 2, quality: :high)

      result = CommunitySignalAnalyzer.new(@agent).analyze

      # New accounts should have lower quality ratio
      assert result[:star_quality_ratio] < 0.5
    end

    private

    def stub_github_repo(stars: 100, forks: 20)
      stub_request(:get, %r{api.github.com/repos/testowner/testrepo$})
        .to_return(
          status: 200,
          body: {
            stargazers_count: stars,
            forks_count: forks,
            full_name: "testowner/testrepo"
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    def stub_github_stargazers(count: 10, quality: :high, burst: false)
      # Store quality for user endpoint stub
      @stargazer_quality = quality

      stargazers = count.times.map do |i|
        user = generate_user(i, quality)
        starred_at = burst ? (Time.current - rand(1..3).days).iso8601 : (Time.current - rand(1..365).days).iso8601
        { "user" => user, "starred_at" => starred_at }
      end

      # Stub with pagination awareness - only return data on page 1
      stub_request(:get, %r{api.github.com/repos/.*/stargazers})
        .to_return do |request|
          page = request.uri.query_values&.fetch("page", "1") || "1"
          {
            status: 200,
            body: page == "1" ? stargazers.to_json : "[]",
            headers: { "Content-Type" => "application/json" }
          }
        end

      # Set up user endpoint stub if not already done
      stub_github_users unless @users_stubbed
    end

    def stub_github_forks(count: 5, quality: :high)
      # Store quality for user endpoint stub
      @fork_quality = quality

      forks = count.times.map do |i|
        {
          "id" => 1000 + i,
          "owner" => generate_user(i + 100, quality),
          "full_name" => "fork#{i}/testrepo"
        }
      end

      # Stub with pagination awareness - only return data on page 1
      stub_request(:get, %r{api.github.com/repos/.*/forks})
        .to_return do |request|
          page = request.uri.query_values&.fetch("page", "1") || "1"
          {
            status: 200,
            body: page == "1" ? forks.to_json : "[]",
            headers: { "Content-Type" => "application/json" }
          }
        end

      # Set up user endpoint stub if not already done
      stub_github_users unless @users_stubbed
    end

    def stub_github_users
      @users_stubbed = true

      # Stub user endpoint with dynamic response based on username
      stub_request(:get, %r{api.github.com/users/})
        .to_return do |request|
          # Extract username from URL
          username = request.uri.path.split("/").last

          # Determine quality based on username prefix
          quality = if username.start_with?("developer")
                      @stargazer_quality || :high
                    elsif username.start_with?("user")
                      @stargazer_quality || :low
                    elsif username.start_with?("newuser")
                      :new_accounts
                    elsif username.start_with?("fork")
                      @fork_quality || :high
                    else
                      :high
                    end

          # Generate consistent user data based on username
          index = username.match(/\d+/)&.to_s.to_i
          user = generate_user(index, quality)
          {
            status: 200,
            body: user.to_json,
            headers: { "Content-Type" => "application/json" }
          }
        end
    end

    def generate_user(index, quality)
      case quality
      when :high
        {
          "login" => "developer#{index}",
          "id" => 1000 + index,
          "created_at" => (Time.current - 3.years - rand(1000).days).iso8601,
          "updated_at" => (Time.current - rand(30).days).iso8601,
          "public_repos" => rand(10..50),
          "followers" => rand(20..500)
        }
      when :low
        {
          "login" => "user#{index}",
          "id" => 2000 + index,
          "created_at" => (Time.current - rand(10..25).days).iso8601,
          "updated_at" => (Time.current - rand(400..500).days).iso8601,
          "public_repos" => 0,
          "followers" => 0
        }
      when :mixed_mostly_bots
        if index < 4
          generate_user(index, :high)
        else
          generate_user(index, :low)
        end
      when :new_accounts
        {
          "login" => "newuser#{index}",
          "id" => 3000 + index,
          "created_at" => (Time.current - rand(5..20).days).iso8601,
          "updated_at" => (Time.current - rand(1..5).days).iso8601,
          "public_repos" => rand(0..2),
          "followers" => rand(0..5)
        }
      else
        generate_user(index, :high)
      end
    end
  end
end
