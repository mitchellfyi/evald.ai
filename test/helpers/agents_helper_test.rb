# frozen_string_literal: true

require "test_helper"

class AgentsHelperTest < ActionView::TestCase
  test "tier_badge_class returns correct class for each tier" do
    assert_includes tier_badge_class("platinum"), "from-slate"
    assert_includes tier_badge_class("gold"), "from-yellow"
    assert_includes tier_badge_class("silver"), "from-gray"
    assert_includes tier_badge_class("bronze"), "from-orange"
    assert_includes tier_badge_class("unrated"), "bg-gray"
  end

  test "tier_label returns correct label for each tier" do
    assert_equal "⭐ Platinum", tier_label("platinum")
    assert_equal "🥇 Gold", tier_label("gold")
    assert_equal "🥈 Silver", tier_label("silver")
    assert_equal "🥉 Bronze", tier_label("bronze")
    assert_equal "Unrated", tier_label("unrated")
    assert_equal "Unrated", tier_label(nil)
  end

  test "score_color_class returns correct class for score ranges" do
    assert_includes score_color_class(95), "green"
    assert_includes score_color_class(85), "green"
    assert_includes score_color_class(75), "yellow"
    assert_includes score_color_class(65), "yellow"
    assert_includes score_color_class(55), "orange"
    assert_includes score_color_class(45), "red"
    assert_includes score_color_class(nil), "gray"
  end

  test "confidence_badge_class returns correct class for each level" do
    assert_includes confidence_badge_class("high"), "green"
    assert_includes confidence_badge_class("medium"), "yellow"
    assert_includes confidence_badge_class("low"), "orange"
    assert_includes confidence_badge_class("insufficient"), "gray"
  end

  test "confidence_label returns human-readable labels" do
    assert_equal "High Confidence", confidence_label("high")
    assert_equal "Medium Confidence", confidence_label("medium")
    assert_equal "Low Confidence", confidence_label("low")
    assert_equal "Insufficient Data", confidence_label("insufficient")
    assert_equal "Insufficient Data", confidence_label(nil)
  end
end
