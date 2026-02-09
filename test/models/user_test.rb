require "test_helper"

class UserTest < ActiveSupport::TestCase
  # Validations
  should validate_presence_of(:email)
  should validate_uniqueness_of(:email).case_insensitive

  # Associations
  should have_many(:api_keys).dependent(:destroy)
  should have_many(:claimed_agents).class_name("Agent").with_foreign_key(:claimed_by_user_id)

  test "factory creates valid user" do
    user = build(:user)
    assert user.valid?
  end

  test "admin? returns true for admin users" do
    admin = build(:user, :admin)
    assert admin.admin?
  end

  test "admin? returns false for regular users" do
    user = build(:user)
    refute user.admin?
  end

  test "email must be unique" do
    create(:user, email: "test@example.com")
    duplicate = build(:user, email: "test@example.com")
    refute duplicate.valid?
    assert_includes duplicate.errors[:email], "has already been taken"
  end
end
