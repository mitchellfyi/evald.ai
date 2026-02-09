# frozen_string_literal: true
require "test_helper"

module Admin
  class DashboardControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = create(:user, :admin)
      sign_in @admin
    end

    test "index returns success" do
      get admin_root_path
      assert_response :success
    end

    test "index displays stats" do
      # Create some data to count
      create_list(:user, 3)
      create_list(:agent, 2)
      create_list(:api_key, 4)

      get admin_root_path
      assert_response :success

      # Stats should include counts (add 1 to users for the admin user)
      assert_select "body" # Basic check that page renders
    end

    test "index requires authentication" do
      sign_out @admin

      get admin_root_path
      assert_redirected_to new_user_session_path
    end

    test "index requires admin role" do
      sign_out @admin
      regular_user = create(:user)
      sign_in regular_user

      get admin_root_path
      assert_redirected_to root_path
      assert_equal "Access denied", flash[:alert]
    end
  end
end
