# frozen_string_literal: true

require "test_helper"

class GithubTrendingServiceTest < ActiveSupport::TestCase
  setup do
    @client = mock("GithubClient")
    @service = GithubTrendingService.new(github_client: @client)
  end

  test "calculate_confidence scores keywords in name/description" do
    repo = {
      "name" => "my-ai-agent",
      "description" => "An autonomous agent",
      "topics" => [],
      "stargazers_count" => 10,
      "pushed_at" => 1.month.ago.iso8601,
      "homepage" => nil,
      "license" => nil
    }

    score = @service.calculate_confidence(repo)
    assert_equal 20, score # keyword match only
  end

  test "calculate_confidence scores relevant topics" do
    repo = {
      "name" => "some-project",
      "description" => "A project",
      "topics" => ["ai-agent", "python"],
      "stargazers_count" => 10,
      "pushed_at" => 1.month.ago.iso8601,
      "homepage" => nil,
      "license" => nil
    }

    score = @service.calculate_confidence(repo)
    assert_equal 15, score # topic match only
  end

  test "calculate_confidence scores stars" do
    repo = {
      "name" => "some-project",
      "description" => "A project",
      "topics" => [],
      "stargazers_count" => 200,
      "pushed_at" => 1.month.ago.iso8601,
      "homepage" => nil,
      "license" => nil
    }

    score = @service.calculate_confidence(repo)
    assert_equal 15, score # stars >= 50
  end

  test "calculate_confidence scores recent activity" do
    repo = {
      "name" => "some-project",
      "description" => "A project",
      "topics" => [],
      "stargazers_count" => 10,
      "pushed_at" => 1.day.ago.iso8601,
      "homepage" => nil,
      "license" => nil
    }

    score = @service.calculate_confidence(repo)
    assert_equal 15, score # recent push
  end

  test "calculate_confidence scores license" do
    repo = {
      "name" => "some-project",
      "description" => "A project",
      "topics" => [],
      "stargazers_count" => 10,
      "pushed_at" => 1.month.ago.iso8601,
      "homepage" => nil,
      "license" => { "key" => "mit" }
    }

    score = @service.calculate_confidence(repo)
    assert_equal 10, score # license present
  end

  test "calculate_confidence aggregates all scores" do
    repo = {
      "name" => "awesome-ai-agent",
      "description" => "An autonomous agent framework",
      "topics" => ["ai-agent", "autonomous", "llm-agent"],
      "stargazers_count" => 500,
      "pushed_at" => 1.day.ago.iso8601,
      "homepage" => "https://example.com",
      "license" => { "key" => "mit" }
    }

    score = @service.calculate_confidence(repo)
    # keywords: 20, topics: 15, stars: 15, activity: 15, docs: 15, license: 10, examples: 10
    assert_equal 100, score
  end

  test "calculate_confidence caps at 100" do
    repo = {
      "name" => "awesome-ai-agent",
      "description" => "An autonomous agent framework with great documentation",
      "topics" => ["ai-agent", "autonomous", "llm-agent"],
      "stargazers_count" => 500,
      "pushed_at" => 1.day.ago.iso8601,
      "homepage" => "https://example.com",
      "license" => { "key" => "mit" }
    }

    score = @service.calculate_confidence(repo)
    assert score <= 100
  end

  test "discover excludes forked repos" do
    forked_repo = {
      "id" => 1,
      "name" => "ai-agent-fork",
      "description" => "Forked agent",
      "html_url" => "https://github.com/user/ai-agent-fork",
      "fork" => true,
      "topics" => ["ai-agent"],
      "stargazers_count" => 200,
      "pushed_at" => 1.day.ago.iso8601,
      "homepage" => nil,
      "license" => { "key" => "mit" },
      "owner" => { "login" => "user" }
    }

    @client.stubs(:search_repositories).returns({ "items" => [forked_repo] })

    result = @service.discover
    assert_empty result
  end

  test "discover excludes already-tracked agents" do
    create(:agent, repo_url: "https://github.com/org/existing-agent")

    existing_repo = {
      "id" => 2,
      "name" => "existing-agent",
      "description" => "An agent",
      "html_url" => "https://github.com/org/existing-agent",
      "fork" => false,
      "topics" => ["ai-agent"],
      "stargazers_count" => 200,
      "pushed_at" => 1.day.ago.iso8601,
      "homepage" => nil,
      "license" => { "key" => "mit" },
      "owner" => { "login" => "org" }
    }

    @client.stubs(:search_repositories).returns({ "items" => [existing_repo] })

    result = @service.discover
    assert_empty result
  end

  test "discover creates pending agents for qualifying repos" do
    qualifying_repo = {
      "id" => 3,
      "name" => "super-ai-agent",
      "description" => "An autonomous AI agent for tasks",
      "html_url" => "https://github.com/org/super-ai-agent",
      "fork" => false,
      "topics" => ["ai-agent", "autonomous", "llm"],
      "stargazers_count" => 500,
      "pushed_at" => 1.day.ago.iso8601,
      "homepage" => "https://example.com",
      "license" => { "key" => "mit" },
      "owner" => { "login" => "org" }
    }

    @client.stubs(:search_repositories).returns({ "items" => [qualifying_repo] })

    assert_difference("PendingAgent.count", 1) do
      @service.discover
    end

    pa = PendingAgent.last
    assert_equal "super-ai-agent", pa.name
    assert_equal "https://github.com/org/super-ai-agent", pa.github_url
    assert_equal "org", pa.owner
    assert pa.confidence_score >= 50
  end

  test "discover skips low-confidence repos" do
    low_quality_repo = {
      "id" => 4,
      "name" => "random-project",
      "description" => "A project",
      "html_url" => "https://github.com/user/random-project",
      "fork" => false,
      "topics" => [],
      "stargazers_count" => 5,
      "pushed_at" => 2.months.ago.iso8601,
      "homepage" => nil,
      "license" => nil,
      "owner" => { "login" => "user" }
    }

    @client.stubs(:search_repositories).returns({ "items" => [low_quality_repo] })

    assert_no_difference("PendingAgent.count") do
      @service.discover
    end
  end
end
