# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

class GithubClientTest < ActiveSupport::TestCase
  setup do
    @client = GithubClient.new(token: "test_token")
    WebMock.enable!
  end

  teardown do
    WebMock.disable!
  end

  # === Collaborator Permission Tests ===

  test "collaborator_permission returns permission data for valid collaborator" do
    stub_request(:get, "https://api.github.com/repos/testowner/testrepo/collaborators/testuser/permission")
      .with(headers: { "Authorization" => "Bearer test_token" })
      .to_return(
        status: 200,
        body: { permission: "admin", user: { login: "testuser" } }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.collaborator_permission("testowner", "testrepo", "testuser")

    assert_not_nil result
    assert_equal "admin", result["permission"]
  end

  test "collaborator_permission returns nil for non-collaborator" do
    stub_request(:get, "https://api.github.com/repos/testowner/testrepo/collaborators/stranger/permission")
      .with(headers: { "Authorization" => "Bearer test_token" })
      .to_return(
        status: 404,
        body: { message: "Not Found" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.collaborator_permission("testowner", "testrepo", "stranger")

    assert_nil result
  end

  test "collaborator_permission returns nil for non-existent repo" do
    stub_request(:get, "https://api.github.com/repos/testowner/nonexistent/collaborators/testuser/permission")
      .with(headers: { "Authorization" => "Bearer test_token" })
      .to_return(
        status: 404,
        body: { message: "Not Found" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.collaborator_permission("testowner", "nonexistent", "testuser")

    assert_nil result
  end

  test "collaborator_permission raises RateLimitError when rate limited" do
    stub_request(:get, "https://api.github.com/repos/testowner/testrepo/collaborators/testuser/permission")
      .with(headers: { "Authorization" => "Bearer test_token" })
      .to_return(
        status: 403,
        body: { message: "API rate limit exceeded for user" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    assert_raises(GithubClient::RateLimitError) do
      @client.collaborator_permission("testowner", "testrepo", "testuser")
    end
  end

  test "collaborator_permission returns nil when forbidden without rate limit" do
    stub_request(:get, "https://api.github.com/repos/testowner/testrepo/collaborators/testuser/permission")
      .with(headers: { "Authorization" => "Bearer test_token" })
      .to_return(
        status: 403,
        body: { message: "Resource not accessible by integration" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.collaborator_permission("testowner", "testrepo", "testuser")

    assert_nil result
  end

  test "collaborator_permission returns nil without token" do
    client_no_token = GithubClient.new(token: nil)

    result = client_no_token.collaborator_permission("testowner", "testrepo", "testuser")

    assert_nil result
  end

  # === Permission Level Tests ===

  test "collaborator_permission returns maintain permission" do
    stub_request(:get, "https://api.github.com/repos/testowner/testrepo/collaborators/maintainer/permission")
      .with(headers: { "Authorization" => "Bearer test_token" })
      .to_return(
        status: 200,
        body: { permission: "maintain", user: { login: "maintainer" } }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.collaborator_permission("testowner", "testrepo", "maintainer")

    assert_equal "maintain", result["permission"]
  end

  test "collaborator_permission returns write permission" do
    stub_request(:get, "https://api.github.com/repos/testowner/testrepo/collaborators/writer/permission")
      .with(headers: { "Authorization" => "Bearer test_token" })
      .to_return(
        status: 200,
        body: { permission: "write", user: { login: "writer" } }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.collaborator_permission("testowner", "testrepo", "writer")

    assert_equal "write", result["permission"]
  end

  test "collaborator_permission returns read permission" do
    stub_request(:get, "https://api.github.com/repos/testowner/testrepo/collaborators/reader/permission")
      .with(headers: { "Authorization" => "Bearer test_token" })
      .to_return(
        status: 200,
        body: { permission: "read", user: { login: "reader" } }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.collaborator_permission("testowner", "testrepo", "reader")

    assert_equal "read", result["permission"]
  end

  # === Stargazers Tests ===

  test "stargazers returns array of stargazers with timestamps" do
    stargazers = [
      { user: { login: "user1", id: 1 }, starred_at: "2024-01-15T10:00:00Z" },
      { user: { login: "user2", id: 2 }, starred_at: "2024-01-16T10:00:00Z" }
    ]

    stub_request(:get, %r{api.github.com/repos/testowner/testrepo/stargazers})
      .to_return(
        status: 200,
        body: stargazers.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.stargazers("testowner", "testrepo")

    assert_equal 2, result.size
    assert_equal "user1", result[0]["user"]["login"]
    assert_equal "2024-01-15T10:00:00Z", result[0]["starred_at"]
  end

  test "stargazers supports pagination" do
    stub_request(:get, %r{api.github.com/repos/testowner/testrepo/stargazers})
      .to_return(
        status: 200,
        body: [{ user: { login: "user3" }, starred_at: "2024-01-17T10:00:00Z" }].to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.stargazers("testowner", "testrepo", per_page: 50, page: 2)

    assert_equal 1, result.size
    assert_equal "user3", result[0]["user"]["login"]
  end

  test "stargazers returns empty array on error" do
    stub_request(:get, %r{api.github.com/repos/testowner/testrepo/stargazers})
      .to_return(status: 500, body: "Internal Server Error")

    result = @client.stargazers("testowner", "testrepo")

    assert_equal [], result
  end

  # === Forks Tests ===

  test "forks returns array of fork data" do
    forks = [
      { id: 1, owner: { login: "forker1" }, full_name: "forker1/testrepo" },
      { id: 2, owner: { login: "forker2" }, full_name: "forker2/testrepo" }
    ]

    stub_request(:get, %r{api.github.com/repos/testowner/testrepo/forks})
      .to_return(
        status: 200,
        body: forks.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.forks("testowner", "testrepo")

    assert_equal 2, result.size
    assert_equal "forker1", result[0]["owner"]["login"]
  end

  test "forks returns empty array on error" do
    stub_request(:get, %r{api.github.com/repos/testowner/testrepo/forks})
      .to_return(status: 404, body: { message: "Not Found" }.to_json)

    result = @client.forks("testowner", "testrepo")

    assert_equal [], result
  end

  # === User Tests ===

  test "user returns user details" do
    user_data = {
      login: "testuser",
      id: 12345,
      created_at: "2020-01-01T00:00:00Z",
      public_repos: 25,
      followers: 100
    }

    stub_request(:get, %r{api.github.com/users/testuser$})
      .to_return(
        status: 200,
        body: user_data.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.user("testuser")

    assert_equal "testuser", result["login"]
    assert_equal 25, result["public_repos"]
    assert_equal 100, result["followers"]
  end

  test "user returns nil on 404 error" do
    stub_request(:get, %r{api.github.com/users/nonexistent$})
      .to_raise(StandardError.new("Not Found"))

    result = @client.user("nonexistent")

    assert_nil result
  end

  # === User Events Tests ===

  test "user_events returns array of public events" do
    events = [
      { type: "PushEvent", created_at: "2024-01-15T10:00:00Z" },
      { type: "CreateEvent", created_at: "2024-01-14T10:00:00Z" }
    ]

    stub_request(:get, %r{api.github.com/users/testuser/events/public})
      .to_return(
        status: 200,
        body: events.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.user_events("testuser")

    assert_equal 2, result.size
    assert_equal "PushEvent", result[0]["type"]
  end

  test "user_events returns empty array on error" do
    stub_request(:get, %r{api.github.com/users/testuser/events/public})
      .to_raise(StandardError.new("Error"))

    result = @client.user_events("testuser")

    assert_equal [], result
  end

  # === Rate Limit Tests ===

  test "rate_limit returns rate limit info" do
    rate_data = {
      rate: { limit: 5000, remaining: 4999, reset: 1234567890 }
    }

    stub_request(:get, %r{api.github.com/rate_limit})
      .to_return(
        status: 200,
        body: rate_data.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.rate_limit

    assert_equal 5000, result["rate"]["limit"]
    assert_equal 4999, result["rate"]["remaining"]
  end

  test "rate_limit returns default on error" do
    stub_request(:get, %r{api.github.com/rate_limit})
      .to_raise(StandardError.new("Error"))

    result = @client.rate_limit

    assert_equal 0, result["rate"]["remaining"]
  end
end
