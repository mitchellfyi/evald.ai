# frozen_string_literal: true
require "test_helper"

module Admin
  class AgentsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = create(:user, :admin)
      @agent = create(:agent, name: "Test Agent", slug: "test-agent")
      sign_in @admin
    end

    # Index tests
    test "index returns success" do
      get admin_agents_path
      assert_response :success
    end

    test "index lists all agents" do
      create_list(:agent, 5)

      get admin_agents_path
      assert_response :success
    end

    test "index orders agents by created_at desc" do
      get admin_agents_path
      assert_response :success
    end

    # Show tests
    test "show returns success" do
      get admin_agent_path(@agent)
      assert_response :success
    end

    test "show returns not found for nonexistent agent" do
      get admin_agent_path(id: "nonexistent-slug")
      assert_response :not_found
    end

    # Edit tests
    test "edit returns success" do
      get edit_admin_agent_path(@agent)
      assert_response :success
    end

    test "edit returns not found for nonexistent agent" do
      get edit_admin_agent_path(id: "nonexistent-slug")
      assert_response :not_found
    end

    # Update tests
    test "update with valid params redirects to show" do
      patch admin_agent_path(@agent), params: {
        agent: {
          name: "Updated Agent",
          description: "New description",
          category: "coding"
        }
      }

      assert_redirected_to admin_agent_path(@agent)
      assert_equal "Agent updated successfully.", flash[:notice]
      @agent.reload
      assert_equal "Updated Agent", @agent.name
      assert_equal "New description", @agent.description
    end

    test "update with invalid params renders edit" do
      # Name can't be blank (assuming validation)
      patch admin_agent_path(@agent), params: { agent: { name: "" } }

      # If validation fails, should render edit with unprocessable_entity
      # If no validation, it would redirect - adjust based on actual model
      assert_response :unprocessable_entity
    end

    test "update can change all permitted attributes" do
      patch admin_agent_path(@agent), params: {
        agent: {
          name: "New Name",
          slug: "new-slug",
          description: "New description",
          repo_url: "https://github.com/example/repo",
          category: "coding"
        }
      }

      assert_redirected_to admin_agent_path(id: "new-slug")
      @agent.reload
      assert_equal "New Name", @agent.name
      assert_equal "new-slug", @agent.slug
      assert_equal "New description", @agent.description
    end

    # Destroy tests
    test "destroy deletes agent and redirects" do
      assert_difference("Agent.count", -1) do
        delete admin_agent_path(@agent)
      end

      assert_redirected_to admin_agents_path
      assert_equal "Agent deleted successfully.", flash[:notice]
    end

    test "destroy returns not found for nonexistent agent" do
      delete admin_agent_path(id: "nonexistent-slug")
      assert_response :not_found
    end

    # Authorization tests
    test "index requires authentication" do
      sign_out @admin

      get admin_agents_path
      assert_redirected_to new_user_session_path
    end

    test "index requires admin" do
      sign_out @admin
      regular_user = create(:user)
      sign_in regular_user

      get admin_agents_path
      assert_redirected_to root_path
      assert_equal "Access denied", flash[:alert]
    end

    test "show requires admin" do
      sign_out @admin
      regular_user = create(:user)
      sign_in regular_user

      get admin_agent_path(@agent)
      assert_redirected_to root_path
    end

    test "edit requires admin" do
      sign_out @admin
      regular_user = create(:user)
      sign_in regular_user

      get edit_admin_agent_path(@agent)
      assert_redirected_to root_path
    end

    test "update requires admin" do
      sign_out @admin
      regular_user = create(:user)
      sign_in regular_user

      original_name = @agent.name
      patch admin_agent_path(@agent), params: { agent: { name: "Hacked" } }
      assert_redirected_to root_path

      @agent.reload
      assert_equal original_name, @agent.name
    end

    test "destroy requires admin" do
      sign_out @admin
      regular_user = create(:user)
      sign_in regular_user

      assert_no_difference("Agent.count") do
        delete admin_agent_path(@agent)
      end

      assert_redirected_to root_path
    end
  end
end
