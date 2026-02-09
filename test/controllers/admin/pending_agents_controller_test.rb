# frozen_string_literal: true

require "test_helper"

module Admin
  class PendingAgentsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = create(:user, :admin)
      @pending_agent = create(:pending_agent)
      sign_in @admin
    end

    # Index tests
    test "index returns success" do
      get admin_pending_agents_path
      assert_response :success
    end

    test "index lists pending agents" do
      create_list(:pending_agent, 3)

      get admin_pending_agents_path
      assert_response :success
    end

    test "index filters by status" do
      create(:pending_agent, :approved)
      create(:pending_agent, :rejected)

      get admin_pending_agents_path(status: "pending")
      assert_response :success
    end

    test "index filters by minimum score" do
      create(:pending_agent, :high_confidence)
      create(:pending_agent, :low_confidence)

      get admin_pending_agents_path(min_score: 80)
      assert_response :success
    end

    # Show tests
    test "show returns success" do
      get admin_pending_agent_path(@pending_agent)
      assert_response :success
    end

    # Approve tests
    test "approve changes status to approved" do
      post approve_admin_pending_agent_path(@pending_agent)

      assert_redirected_to admin_pending_agents_path
      @pending_agent.reload
      assert_equal "approved", @pending_agent.status
      assert_equal @admin, @pending_agent.reviewed_by
      assert_not_nil @pending_agent.reviewed_at
    end

    # Reject tests
    test "reject changes status to rejected" do
      post reject_admin_pending_agent_path(@pending_agent), params: {
        rejection_reason: "Not a real agent"
      }

      assert_redirected_to admin_pending_agents_path
      @pending_agent.reload
      assert_equal "rejected", @pending_agent.status
      assert_equal "Not a real agent", @pending_agent.rejection_reason
    end

    # Authorization tests
    test "index requires authentication" do
      sign_out @admin

      get admin_pending_agents_path
      assert_redirected_to new_user_session_path
    end

    test "index requires admin" do
      sign_out @admin
      regular_user = create(:user)
      sign_in regular_user

      get admin_pending_agents_path
      assert_redirected_to root_path
      assert_equal "Access denied", flash[:alert]
    end

    test "approve requires admin" do
      sign_out @admin
      regular_user = create(:user)
      sign_in regular_user

      post approve_admin_pending_agent_path(@pending_agent)
      assert_redirected_to root_path

      @pending_agent.reload
      assert_equal "pending", @pending_agent.status
    end

    test "reject requires admin" do
      sign_out @admin
      regular_user = create(:user)
      sign_in regular_user

      post reject_admin_pending_agent_path(@pending_agent)
      assert_redirected_to root_path

      @pending_agent.reload
      assert_equal "pending", @pending_agent.status
    end
  end
end
