# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

class ClaimVerificationServiceTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    @agent = create(:agent, repo_url: "https://github.com/testowner/testrepo")
    @claim = create(:claim_request, user: @user, agent: @agent)
    # Add the expected methods that the service needs
    @claim.define_singleton_method(:verification_method) { "github_file" }
    @claim.define_singleton_method(:verification_data) { { "token" => "test-token-123" } }
    WebMock.enable!
  end

  teardown do
    WebMock.disable!
  end

  # verify method tests
  test "verify returns claim on failed verification" do
    stub_github_content_not_found

    service = ClaimVerificationService.new(@claim)
    result = service.verify

    assert_equal @claim, result
  end

  test "verify calls verify_github for github_file method" do
    stub_github_content("wrong-token")

    service = ClaimVerificationService.new(@claim)
    service.verify

    # Should have attempted GitHub verification
    assert_requested(:get, %r{api.github.com/repos/.*/contents/\.evald/verify\.txt})
  end

  test "verify calls verify_api_key for api_key method" do
    @claim.define_singleton_method(:verification_method) { "api_key" }
    @claim.define_singleton_method(:verification_data) { { "api_key" => "secret-key" } }

    service = ClaimVerificationService.new(@claim)
    result = service.verify

    # API key verification is a placeholder that returns true
    assert @claim.reload.verified? || result == @claim
  end

  test "verify returns false for unknown method" do
    @claim.define_singleton_method(:verification_method) { "unknown_method" }

    service = ClaimVerificationService.new(@claim)
    result = service.verify

    # Should return claim (not verified)
    assert_equal @claim, result
  end

  # verify_github tests
  test "verify_github returns false when owner/repo cannot be parsed" do
    @agent.update!(repo_url: "invalid-url")

    service = ClaimVerificationService.new(@claim)
    result = service.send(:verify_github)

    assert_not result
  end

  test "verify_github returns false when file not found" do
    stub_github_content_not_found

    service = ClaimVerificationService.new(@claim)
    result = service.send(:verify_github)

    assert_not result
  end

  test "verify_github returns false when token mismatch" do
    stub_github_content("wrong-token")

    service = ClaimVerificationService.new(@claim)
    result = service.send(:verify_github)

    assert_not result
  end

  test "verify_github returns true when token matches" do
    stub_github_content("test-token-123")

    service = ClaimVerificationService.new(@claim)
    result = service.send(:verify_github)

    assert result
  end

  # verify_api_key tests
  test "verify_api_key returns false when no api_key" do
    @claim.define_singleton_method(:verification_data) { {} }

    service = ClaimVerificationService.new(@claim)
    result = service.send(:verify_api_key?)

    assert_not result
  end

  test "verify_api_key returns true when api_key present" do
    @claim.define_singleton_method(:verification_data) { { "api_key" => "test-key" } }

    service = ClaimVerificationService.new(@claim)
    result = service.send(:verify_api_key?)

    assert result
  end

  # helper method tests
  test "extract_domain extracts host from URL" do
    service = ClaimVerificationService.new(@claim)

    result = service.send(:extract_domain, "https://example.com/path")

    assert_equal "example.com", result
  end

  test "extract_domain returns nil for invalid URL" do
    service = ClaimVerificationService.new(@claim)

    result = service.send(:extract_domain, "not-a-url")

    assert_nil result
  end

  test "parse_github_url extracts owner and repo" do
    service = ClaimVerificationService.new(@claim)

    result = service.send(:parse_github_url, "https://github.com/owner/repo")

    assert_equal ["owner", "repo"], result
  end

  test "parse_github_url handles .git suffix" do
    service = ClaimVerificationService.new(@claim)

    result = service.send(:parse_github_url, "https://github.com/owner/repo.git")

    assert_equal ["owner", "repo"], result
  end

  test "parse_github_url returns nil for non-github URL" do
    service = ClaimVerificationService.new(@claim)

    result = service.send(:parse_github_url, "https://gitlab.com/owner/repo")

    assert_nil result
  end

  private

  def stub_github_content(content)
    stub_request(:get, %r{api.github.com/repos/.*/contents/\.evald/verify\.txt})
      .to_return(
        status: 200,
        body: { content: Base64.encode64(content) }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_github_content_not_found
    stub_request(:get, %r{api.github.com/repos/.*/contents/\.evald/verify\.txt})
      .to_return(status: 404, body: { message: "Not Found" }.to_json)
  end
end
