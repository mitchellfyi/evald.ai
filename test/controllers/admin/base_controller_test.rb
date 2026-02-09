# frozen_string_literal: true
require "test_helper"

module Admin
  class BaseControllerTest < ActionDispatch::IntegrationTest
    test "unauthenticated user is redirected to sign in" do
      get admin_root_path
      assert_redirected_to new_user_session_path
    end

    test "non-admin user is redirected with access denied" do
      user = create(:user)
      sign_in user

      get admin_root_path
      assert_redirected_to root_path
      assert_equal "Access denied", flash[:alert]
    end

    test "admin user can access admin area" do
      admin = create(:user, :admin)
      sign_in admin

      get admin_root_path
      assert_response :success
    end
  end
end
