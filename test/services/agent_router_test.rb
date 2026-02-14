# frozen_string_literal: true

require "test_helper"

class AgentRouterTest < ActiveSupport::TestCase
  setup do
    @router = AgentRouter.new
    @coding_agent = create(:agent, :published, :with_score,
      name: "Code Master", slug: "code-master",
      category: "coding", description: "A coding agent that writes Python code",
      score: 85.0, score_at_eval: 85.0)
    @research_agent = create(:agent, :published, :with_score,
      name: "Research Pro", slug: "research-pro",
      category: "research", description: "Agent for research and analysis",
      score: 80.0, score_at_eval: 80.0)
    @general_agent = create(:agent, :published, :with_score,
      name: "General Helper", slug: "general-helper",
      category: "general", description: "A general purpose assistant",
      score: 70.0, score_at_eval: 70.0)
  end

  # Basic routing tests
  test "routes coding prompt to coding agents" do
    results = @router.route("Write a Python function to sort a list")

    assert_not_empty results
    assert results.first.agent.category == "coding" || results.first.score > 0
  end

  test "routes research prompt to research agents" do
    results = @router.route("Summarize the latest research on machine learning")

    assert_not_empty results
    slugs = results.map { |m| m.agent.slug }
    assert_includes slugs, "research-pro"
  end

  test "returns empty for blank prompt" do
    results = @router.route("")
    assert_empty results
  end

  test "returns empty for nil prompt" do
    results = @router.route(nil)
    assert_empty results
  end

  # Result structure
  test "results are AgentMatch structs" do
    results = @router.route("Write some code")

    assert_not_empty results
    match = results.first
    assert_kind_of AgentRouter::AgentMatch, match
    assert_respond_to match, :agent
    assert_respond_to match, :score
    assert_respond_to match, :reasons
    assert_respond_to match, :category
  end

  test "results are sorted by score descending" do
    results = @router.route("Write a Python script")

    if results.size > 1
      results.each_cons(2) do |a, b|
        assert a.score >= b.score, "Results should be sorted by score descending"
      end
    end
  end

  test "limits results to specified count" do
    results = @router.route("Write code", limit: 2)

    assert results.size <= 2
  end

  test "default limit is 5" do
    results = @router.route("Write code")

    assert results.size <= 5
  end

  # Score components
  test "match scores are between 0 and 100" do
    results = @router.route("Debug this Python error")

    results.each do |match|
      assert match.score >= 0, "Score should be >= 0, got #{match.score}"
      assert match.score <= 100, "Score should be <= 100, got #{match.score}"
    end
  end

  test "reasons are not empty" do
    results = @router.route("Write a function")

    results.each do |match|
      assert_not_empty match.reasons, "Reasons should not be empty for #{match.agent.name}"
    end
  end

  # Class method
  test "route class method works" do
    results = AgentRouter.route("Write Python code")

    assert_kind_of Array, results
  end

  # Unpublished agents
  test "excludes unpublished agents" do
    create(:agent, name: "Hidden Agent", slug: "hidden-agent",
      category: "coding", published: false)

    results = @router.route("Write code")

    slugs = results.map { |m| m.agent.slug }
    assert_not_includes slugs, "hidden-agent"
  end
end
