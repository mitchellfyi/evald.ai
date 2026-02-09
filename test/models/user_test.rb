require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "factory creates valid user" do
    user = build(:user)
    assert user.valid?
  end

  test "requires email" do
    user = build(:user, email: nil)
    refute user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "email must be unique" do
    create(:user, email: "test@example.com")
    duplicate = build(:user, email: "test@example.com")
    refute duplicate.valid?
    assert_includes duplicate.errors[:email], "has already been taken"
  end

  test "admin? returns true for admin users" do
    admin = build(:user, :admin)
    assert admin.admin?
  end

  test "admin? returns false for regular users" do
    user = build(:user)
    refute user.admin?
  end
end
