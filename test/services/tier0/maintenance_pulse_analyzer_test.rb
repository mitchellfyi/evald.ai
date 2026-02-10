# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

module Tier0
  class MaintenancePulseAnalyzerTest < ActiveSupport::TestCase
    setup do
      @agent = create(:agent, repo_url: "https://github.com/testowner/testrepo")
      WebMock.enable!
    end

    teardown do
      WebMock.disable!
    end

    test "analyze returns hash with expected keys" do
      stub_repo_info(pushed_days_ago: 5)
      stub_releases(count: 6)
      stub_issues(count: 10)

      result = MaintenancePulseAnalyzer.new(@agent).analyze

      assert result.key?(:days_since_last_commit)
      assert result.key?(:commit_recency_score)
      assert result.key?(:release_count_last_year)
      assert result.key?(:release_cadence_score)
      assert result.key?(:issue_response_score)
      assert result.key?(:score)
    end

    test "returns zero score when repo not found" do
      stub_request(:get, %r{api.github.com/repos/testowner/testrepo$})
        .to_return(status: 404, body: { message: "Not Found" }.to_json)
      stub_releases(count: 0)
      stub_issues(count: 0)

      result = MaintenancePulseAnalyzer.new(@agent).analyze

      assert_equal 0, result[:score]
    end

    test "high commit recency score for recent commits" do
      stub_repo_info(pushed_days_ago: 3)
      stub_releases(count: 0)
      stub_issues(count: 0)

      result = MaintenancePulseAnalyzer.new(@agent).analyze

      assert_equal 50, result[:commit_recency_score]
    end

    test "high release cadence score for monthly releases" do
      stub_repo_info(pushed_days_ago: 5)
      stub_releases(count: 12)
      stub_issues(count: 0)

      result = MaintenancePulseAnalyzer.new(@agent).analyze

      assert_equal 25, result[:release_cadence_score]
    end

    test "high issue response score for fast response times" do
      stub_repo_info(pushed_days_ago: 5)
      stub_releases(count: 0)
      stub_issues(count: 10, response_hours: 24)

      result = MaintenancePulseAnalyzer.new(@agent).analyze

      assert_equal 25, result[:issue_response_score]
    end

    test "perfect score for well-maintained project" do
      stub_repo_info(pushed_days_ago: 1)
      stub_releases(count: 15)
      stub_issues(count: 10, response_hours: 12)

      result = MaintenancePulseAnalyzer.new(@agent).analyze

      assert_equal 100, result[:score]
    end

    private

    def stub_repo_info(pushed_days_ago:)
      stub_request(:get, %r{api.github.com/repos/testowner/testrepo$})
        .to_return(status: 200, body: {
          name: "testrepo",
          full_name: "testowner/testrepo",
          pushed_at: pushed_days_ago.days.ago.iso8601
        }.to_json, headers: { "Content-Type" => "application/json" })
    end

    def stub_releases(count:)
      releases = count.times.map { |i| { id: i + 1, published_at: (30 * (i + 1)).days.ago.iso8601 } }
      stub_request(:get, %r{api.github.com/repos/testowner/testrepo/releases})
        .to_return(status: 200, body: releases.to_json, headers: { "Content-Type" => "application/json" })
    end

    def stub_issues(count:, response_hours: 24)
      issues = count.times.map do |i|
        created_at = (30 + i * 7).days.ago
        { id: i + 1, state: "closed", created_at: created_at.iso8601, updated_at: (created_at + response_hours.hours).iso8601, comments: 2 }
      end
      stub_request(:get, %r{api.github.com/repos/testowner/testrepo/issues})
        .to_return(status: 200, body: issues.to_json, headers: { "Content-Type" => "application/json" })
    end
  end
end
