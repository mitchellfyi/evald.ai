# frozen_string_literal: true

require "test_helper"

class NotificationPreferenceTest < ActiveSupport::TestCase
  test "valid notification preference" do
    pref = build(:notification_preference)
    assert pref.valid?
  end

  test "requires user" do
    pref = build(:notification_preference, user: nil)
    assert_not pref.valid?
  end

  test "requires agent" do
    pref = build(:notification_preference, agent: nil)
    assert_not pref.valid?
  end

  test "enforces uniqueness per user and agent" do
    existing = create(:notification_preference)
    duplicate = build(:notification_preference, user: existing.user, agent: existing.agent)
    assert_not duplicate.valid?
  end

  test "defaults score_changes to true" do
    pref = NotificationPreference.new
    assert_equal true, pref.score_changes
  end

  test "defaults new_eval_results to true" do
    pref = NotificationPreference.new
    assert_equal true, pref.new_eval_results
  end
end
