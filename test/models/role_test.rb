# frozen_string_literal: true

require "test_helper"

class RoleTest < ActiveSupport::TestCase
  test "factory creates valid role" do
    role = build(:role)
    assert role.valid?
  end

  test "can be created with a name" do
    role = create(:role, name: "editor")
    assert_equal "editor", role.name
  end

  test "resource_type validates inclusion in Rolify resource_types" do
    role = build(:role, resource_type: "InvalidType")
    refute role.valid?
    assert_includes role.errors[:resource_type], "is not included in the list"
  end

  test "resource_type allows nil" do
    role = build(:role, resource_type: nil)
    assert role.valid?
  end

  test "supports optional polymorphic resource" do
    role = build(:role, resource: nil)
    assert role.valid?
  end
end
