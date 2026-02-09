# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

module Tier0
  class DependencyRiskAnalyzerTest < ActiveSupport::TestCase
    setup do
      @agent = create(:agent, repo_url: "https://github.com/testowner/testrepo")
      WebMock.enable!
    end

    teardown do
      WebMock.disable!
    end

    test "analyze returns hash with expected keys" do
      stub_all_github_apis

      result = DependencyRiskAnalyzer.new(@agent).analyze

      assert result.key?(:has_lockfile)
      assert result.key?(:dependency_count)
      assert result.key?(:security_alerts)
      assert result.key?(:score)
    end

    test "has_lockfile is true when package-lock exists" do
      stub_contents("package-lock.json", content: "{}")
      stub_default_contents
      stub_dependabot_alerts(count: 0)

      result = DependencyRiskAnalyzer.new(@agent).analyze

      assert result[:has_lockfile]
    end

    test "has_lockfile is true when Gemfile.lock exists" do
      stub_contents("Gemfile.lock", content: "GEM")
      stub_default_contents
      stub_dependabot_alerts(count: 0)

      result = DependencyRiskAnalyzer.new(@agent).analyze

      assert result[:has_lockfile]
    end

    test "has_lockfile is false when no lockfile exists" do
      stub_default_contents
      stub_dependabot_alerts(count: 0)

      result = DependencyRiskAnalyzer.new(@agent).analyze

      assert_not result[:has_lockfile]
    end

    test "counts dependencies from package.json" do
      package_json = {
        dependencies: { "react" => "^18.0", "lodash" => "^4.0" },
        devDependencies: { "jest" => "^29.0" }
      }
      stub_contents("package.json", content: package_json.to_json)
      stub_default_contents
      stub_dependabot_alerts(count: 0)

      result = DependencyRiskAnalyzer.new(@agent).analyze

      assert_equal 3, result[:dependency_count]
    end

    test "counts dependencies from Gemfile" do
      gemfile = "source 'https://rubygems.org'\ngem 'rails'\ngem 'puma'\ngem 'pg'"
      stub_contents("Gemfile", content: gemfile)
      stub_default_contents
      stub_dependabot_alerts(count: 0)

      result = DependencyRiskAnalyzer.new(@agent).analyze

      assert_equal 3, result[:dependency_count]
    end

    test "counts dependencies from requirements.txt" do
      requirements = "django>=4.0\nrequests\n# comment\npytest"
      stub_contents("requirements.txt", content: requirements)
      stub_default_contents
      stub_dependabot_alerts(count: 0)

      result = DependencyRiskAnalyzer.new(@agent).analyze

      assert_equal 3, result[:dependency_count]
    end

    test "security_alerts returns count of open alerts" do
      stub_default_contents
      stub_dependabot_alerts(count: 3)

      result = DependencyRiskAnalyzer.new(@agent).analyze

      assert_equal 3, result[:security_alerts]
    end

    test "security_alerts returns 0 when no alerts" do
      stub_default_contents
      stub_dependabot_alerts(count: 0)

      result = DependencyRiskAnalyzer.new(@agent).analyze

      assert_equal 0, result[:security_alerts]
    end

    test "score is 100 with no alerts and lockfile" do
      stub_contents("package-lock.json", content: "{}")
      stub_default_contents
      stub_dependabot_alerts(count: 0)

      result = DependencyRiskAnalyzer.new(@agent).analyze

      assert_equal 100, result[:score]
    end

    test "score reduces by 15 per open alert" do
      stub_contents("package-lock.json", content: "{}")
      stub_default_contents
      stub_dependabot_alerts(count: 2)

      result = DependencyRiskAnalyzer.new(@agent).analyze

      assert_equal 70, result[:score]  # 100 - 30
    end

    test "score reduces by 20 for no lockfile" do
      stub_default_contents
      stub_dependabot_alerts(count: 0)

      result = DependencyRiskAnalyzer.new(@agent).analyze

      assert_equal 80, result[:score]  # 100 - 20
    end

    test "score floors at 0" do
      stub_default_contents
      stub_dependabot_alerts(count: 10)

      result = DependencyRiskAnalyzer.new(@agent).analyze

      assert_equal 0, result[:score]
    end

    test "handles non-array alerts response" do
      stub_default_contents
      stub_request(:get, %r{api.github.com/repos/.*/dependabot/alerts})
        .to_return(status: 200, body: { message: "Not Found" }.to_json)

      result = DependencyRiskAnalyzer.new(@agent).analyze

      assert_equal 0, result[:security_alerts]
    end

    private

    def stub_contents(path, content:)
      stub_request(:get, %r{api.github.com/repos/.*/contents/#{Regexp.escape(path)}})
        .to_return(
          status: 200,
          body: { content: Base64.encode64(content) }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    def stub_default_contents
      # Stub 404 for all content requests that aren't specifically stubbed
      stub_request(:get, %r{api.github.com/repos/.*/contents/})
        .to_return(status: 404, body: { message: "Not Found" }.to_json)
    end

    def stub_dependabot_alerts(count:)
      alerts = count.times.map do |i|
        {
          state: "open",
          security_vulnerability: { package: { name: "vuln-#{i}" }, severity: "high" }
        }
      end
      stub_request(:get, %r{api.github.com/repos/.*/dependabot/alerts})
        .to_return(status: 200, body: alerts.to_json, headers: { "Content-Type" => "application/json" })
    end

    def stub_all_github_apis
      stub_default_contents
      stub_dependabot_alerts(count: 0)
    end
  end
end
