# frozen_string_literal: true

require "test_helper"

class ClaimProfileFlowTest < ActionDispatch::IntegrationTest
  setup do
    @agent = create(:agent, :published,
      name: "TestAgent",
      slug: "test-agent",
      repo_url: "https://github.com/testuser/test-agent"
    )
    @user = create(:user, github_username: "testuser", github_uid: "12345")
  end

  # === Agent Show Page — Claim CTA ===

  test "unclaimed agent show page displays claim CTA" do
    get agent_path(@agent)
    assert_response :success
    assert_select "h3", text: /Are you the builder of #{@agent.name}/
    assert_select "a", text: /Sign in to Claim/
  end

  test "claimed agent show page does not display claim CTA" do
    @agent.update!(claim_status: "claimed", claimed_by_user: @user)

    get agent_path(@agent)
    assert_response :success
    assert_select "h3", text: /Are you the builder/, count: 0
  end

  test "unclaimed agent shows unclaimed badge" do
    get agent_path(@agent)
    assert_response :success
    assert_select "span", text: /Unclaimed/
  end

  test "claimed agent shows claimed badge" do
    @agent.update!(claim_status: "claimed", claimed_by_user: @user)

    get agent_path(@agent)
    assert_response :success
    assert_select "span", text: /Claimed/
  end

  test "verified agent shows verified badge" do
    @agent.update!(claim_status: "verified", claimed_by_user: @user)

    get agent_path(@agent)
    assert_response :success
    assert_select "span", text: /Verified/
  end

  # === Builder Dashboard ===

  test "unauthenticated user cannot access builder dashboard" do
    get builder_root_path
    assert_redirected_to new_user_session_path
  end

  test "authenticated user can access builder dashboard" do
    sign_in @user
    get builder_root_path
    assert_response :success
    assert_select "h1", text: "Builder Dashboard"
  end

  test "builder dashboard shows claimed agents" do
    @agent.update!(claim_status: "claimed", claimed_by_user: @user)

    sign_in @user
    get builder_root_path
    assert_response :success
    assert_select "h2 a", text: @agent.name
  end

  test "builder dashboard shows empty state when no claimed agents" do
    sign_in @user
    get builder_root_path
    assert_response :success
    assert_select "h2", text: "No claimed agents yet"
  end

  # === Builder Agent Edit ===

  test "owner can edit their claimed agent" do
    @agent.update!(claim_status: "claimed", claimed_by_user: @user)

    sign_in @user
    get edit_builder_agent_path(@agent)
    assert_response :success
  end

  test "non-owner cannot edit agent" do
    other_user = create(:user)
    @agent.update!(claim_status: "claimed", claimed_by_user: other_user)

    sign_in @user
    get edit_builder_agent_path(@agent)
    assert_redirected_to builder_root_path
  end

  test "owner can update builder-editable fields" do
    @agent.update!(claim_status: "claimed", claimed_by_user: @user)

    sign_in @user
    patch builder_agent_path(@agent), params: {
      agent: {
        description: "Updated description",
        tagline: "Best agent ever",
        use_case: "Code review automation",
        documentation_url: "https://docs.example.com",
        changelog_url: "https://example.com/changelog",
        demo_url: "https://demo.example.com"
      }
    }

    assert_redirected_to edit_builder_agent_path(@agent)
    @agent.reload
    assert_equal "Updated description", @agent.description
    assert_equal "Best agent ever", @agent.tagline
    assert_equal "Code review automation", @agent.use_case
    assert_equal "https://docs.example.com", @agent.documentation_url
  end

  test "owner cannot update score or eval fields" do
    @agent.update!(claim_status: "claimed", claimed_by_user: @user, score: 80.0)

    sign_in @user
    patch builder_agent_path(@agent), params: {
      agent: {
        score: 100.0,
        claim_status: "verified",
        name: "HackedAgent"
      }
    }

    @agent.reload
    assert_equal 80.0, @agent.score.to_f
    assert_equal "claimed", @agent.claim_status
    assert_equal "TestAgent", @agent.name
  end

  # === Notification Preferences ===

  test "owner can update notification preferences" do
    @agent.update!(claim_status: "claimed", claimed_by_user: @user)

    sign_in @user
    patch builder_agent_notification_preferences_path(@agent), params: {
      notification_preference: {
        score_changes: true,
        new_eval_results: false,
        comparison_mentions: true,
        email_enabled: true
      }
    }

    assert_redirected_to edit_builder_agent_path(@agent)
    pref = NotificationPreference.find_by(user: @user, agent: @agent)
    assert pref.score_changes
    assert_not pref.new_eval_results
    assert pref.comparison_mentions
  end

  # === Agent Model Claim Statuses ===

  test "agent claim_status defaults to unclaimed" do
    agent = create(:agent)
    assert_equal "unclaimed", agent.claim_status
  end

  test "CLAIM_STATUSES includes unclaimed, claimed, and verified" do
    assert_equal %w[unclaimed claimed verified], Agent::CLAIM_STATUSES
  end

  # === User OAuth ===

  test "User.from_omniauth creates new user" do
    auth = OmniAuth::AuthHash.new(
      uid: "999",
      info: OmniAuth::AuthHash::InfoHash.new(
        nickname: "newuser",
        email: "newuser@example.com",
        name: "New User",
        image: "https://avatars.example.com/999"
      )
    )

    user = User.from_omniauth(auth)
    assert user.persisted?
    assert_equal "999", user.github_uid
    assert_equal "newuser", user.github_username
    assert_equal "newuser@example.com", user.email
  end

  test "User.from_omniauth finds existing user by github_uid" do
    auth = OmniAuth::AuthHash.new(
      uid: @user.github_uid,
      info: OmniAuth::AuthHash::InfoHash.new(
        nickname: "testuser",
        email: @user.email,
        name: "Test User",
        image: nil
      )
    )

    user = User.from_omniauth(auth)
    assert_equal @user.id, user.id
  end

  test "User.from_omniauth links to existing user by email" do
    existing = create(:user, email: "linked@example.com")
    auth = OmniAuth::AuthHash.new(
      uid: "888",
      info: OmniAuth::AuthHash::InfoHash.new(
        nickname: "linkeduser",
        email: "linked@example.com",
        name: "Linked User",
        image: nil
      )
    )

    user = User.from_omniauth(auth)
    assert_equal existing.id, user.id
    assert_equal "888", user.github_uid
  end

  # === Builder-editable fields shown on agent page ===

  test "agent show page displays builder-added links" do
    @agent.update!(
      claim_status: "claimed",
      claimed_by_user: @user,
      tagline: "The best coding agent",
      documentation_url: "https://docs.example.com",
      demo_url: "https://demo.example.com"
    )

    get agent_path(@agent)
    assert_response :success
    assert_match "The best coding agent", response.body
    assert_select "a[href='https://docs.example.com']", text: /Docs/
    assert_select "a[href='https://demo.example.com']", text: /Demo/
  end
end
