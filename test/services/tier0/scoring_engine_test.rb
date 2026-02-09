# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

module Tier0
  class ScoringEngineTest < ActiveSupport::TestCase
    setup do
      @agent = create(:agent, repo_url: "https://github.com/testowner/testrepo")
      WebMock.enable!
      stub_all_github_apis
    end

    teardown do
      WebMock.disable!
    end

    test "evaluate creates an AgentScore record" do
      assert_difference -> { AgentScore.count }, 1 do
        ScoringEngine.new(@agent).evaluate
      end
    end

    test "evaluate creates score with tier 0" do
      score = ScoringEngine.new(@agent).evaluate

      assert_equal 0, score.tier
    end

    test "evaluate creates score with overall_score between 0 and 100" do
      score = ScoringEngine.new(@agent).evaluate

      assert score.overall_score >= 0
      assert score.overall_score <= 100
    end

    test "evaluate creates score with breakdown" do
      score = ScoringEngine.new(@agent).evaluate

      assert score.breakdown.present?
      assert score.breakdown.key?("repo_health")
      assert score.breakdown.key?("bus_factor")
      assert score.breakdown.key?("dependency_risk")
      assert score.breakdown.key?("documentation")
    end

    test "evaluate sets evaluated_at" do
      score = ScoringEngine.new(@agent).evaluate

      assert score.evaluated_at.present?
      assert score.evaluated_at <= Time.current
    end

    test "evaluate sets expires_at in the future" do
      score = ScoringEngine.new(@agent).evaluate

      assert score.expires_at.present?
      assert score.expires_at > Time.current
    end

    test "expires_at is 30 days from evaluation" do
      freeze_time do
        score = ScoringEngine.new(@agent).evaluate
        expected_expiry = 30.days.from_now

        assert_in_delta expected_expiry.to_i, score.expires_at.to_i, 1
      end
    end

    test "score belongs to the correct agent" do
      score = ScoringEngine.new(@agent).evaluate

      assert_equal @agent.id, score.agent_id
    end

    test "weights sum to 1.0" do
      weights = ScoringEngine::WEIGHTS.values.sum

      assert_in_delta 1.0, weights, 0.001
    end

    test "multiple evaluations create separate records" do
      score1 = ScoringEngine.new(@agent).evaluate
      score2 = ScoringEngine.new(@agent).evaluate

      assert_not_equal score1.id, score2.id
    end

    test "breakdown includes repo_health with score" do
      score = ScoringEngine.new(@agent).evaluate

      assert score.breakdown["repo_health"].present?
      assert score.breakdown["repo_health"].key?("score")
    end

    test "breakdown includes bus_factor with score" do
      score = ScoringEngine.new(@agent).evaluate

      assert score.breakdown["bus_factor"].present?
      assert score.breakdown["bus_factor"].key?("score")
    end

    test "breakdown includes dependency_risk with score" do
      score = ScoringEngine.new(@agent).evaluate

      assert score.breakdown["dependency_risk"].present?
      assert score.breakdown["dependency_risk"].key?("score")
    end

    test "breakdown includes documentation with score" do
      score = ScoringEngine.new(@agent).evaluate

      assert score.breakdown["documentation"].present?
      assert score.breakdown["documentation"].key?("score")
    end

    private

    def stub_all_github_apis
      # Stub base repo endpoint (for CommunitySignalAnalyzer)
      repo_data = {
        name: "testrepo",
        full_name: "testowner/testrepo",
        stargazers_count: 100,
        forks_count: 20,
        open_issues_count: 5
      }
      stub_request(:get, %r{api.github.com/repos/[^/]+/[^/]+$})
        .to_return(status: 200, body: repo_data.to_json, headers: { "Content-Type" => "application/json" })

      # Stub commits
      commits = 50.times.map do |i|
        { sha: SecureRandom.hex(20), commit: { committer: { date: 5.days.ago.iso8601 }, message: "Commit #{i}" } }
      end
      stub_request(:get, %r{api.github.com/repos/.*/commits})
        .to_return(status: 200, body: commits.to_json, headers: { "Content-Type" => "application/json" })

      # Stub issues
      issues = 10.times.map { |i| { state: i < 3 ? "open" : "closed" } }
      stub_request(:get, %r{api.github.com/repos/.*/issues})
        .to_return(status: 200, body: issues.to_json, headers: { "Content-Type" => "application/json" })

      # Stub contributors
      contributors = 5.times.map { |i| { login: "user#{i}", contributions: 100 - i * 20 } }
      stub_request(:get, %r{api.github.com/repos/.*/contributors})
        .to_return(status: 200, body: contributors.to_json, headers: { "Content-Type" => "application/json" })

      # Stub contents for README
      readme = { content: Base64.encode64("# Test Project\n\nThis is a test.") }
      stub_request(:get, %r{api.github.com/repos/.*/readme})
        .to_return(status: 200, body: readme.to_json, headers: { "Content-Type" => "application/json" })

      # Stub contents for dependency files
      stub_request(:get, %r{api.github.com/repos/.*/contents})
        .to_return(status: 404, body: { message: "Not Found" }.to_json)

      # Stub dependabot alerts
      stub_request(:get, %r{api.github.com/repos/.*/dependabot/alerts})
        .to_return(status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" })

      # Stub stargazers (for CommunitySignalAnalyzer)
      stargazers = 10.times.map do |i|
        {
          starred_at: (i.days.ago).iso8601,
          user: {
            login: "stargazer#{i}",
            id: 1000 + i,
            created_at: 2.years.ago.iso8601,
            public_repos: 10,
            followers: 50
          }
        }
      end
      stub_request(:get, %r{api.github.com/repos/.*/stargazers})
        .to_return(status: 200, body: stargazers.to_json, headers: { "Content-Type" => "application/json" })

      # Stub forks (for CommunitySignalAnalyzer)
      forks = 5.times.map do |i|
        {
          id: 2000 + i,
          full_name: "forker#{i}/testrepo",
          owner: {
            login: "forker#{i}",
            id: 3000 + i,
            created_at: 1.year.ago.iso8601,
            public_repos: 5,
            followers: 20
          }
        }
      end
      stub_request(:get, %r{api.github.com/repos/.*/forks})
        .to_return(status: 200, body: forks.to_json, headers: { "Content-Type" => "application/json" })

      # Stub user endpoint (for account quality scoring)
      stub_request(:get, %r{api.github.com/users/})
        .to_return(status: 200, body: {
          login: "testuser",
          id: 12345,
          created_at: 2.years.ago.iso8601,
          updated_at: 1.week.ago.iso8601,
          public_repos: 15,
          followers: 30
        }.to_json, headers: { "Content-Type" => "application/json" })
    end
  end
end
