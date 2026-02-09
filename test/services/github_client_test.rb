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
end
