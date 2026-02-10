# frozen_string_literal: true

require "test_helper"

class TagTest < ActiveSupport::TestCase
  test "factory creates valid tag" do
    tag = build(:tag)
    assert tag.valid?
  end

  test "requires name" do
    tag = build(:tag, name: nil)
    refute tag.valid?
    assert_includes tag.errors[:name], "can't be blank"
  end

  test "name must be unique (case insensitive)" do
    create(:tag, name: "Machine Learning")
    duplicate = build(:tag, name: "machine learning")
    refute duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "slug must be unique" do
    create(:tag, name: "Machine Learning")
    tag = build(:tag, name: "Different Name", slug: "machine-learning")
    refute tag.valid?
    assert_includes tag.errors[:slug], "has already been taken"
  end

  test "slug format must be lowercase alphanumeric with dashes" do
    tag = build(:tag, slug: "Invalid Slug!")
    refute tag.valid?
    assert_includes tag.errors[:slug], "is invalid"
  end

  test "generates slug from name on create" do
    tag = create(:tag, name: "Machine Learning")
    assert_equal "machine-learning", tag.slug
  end

  test "does not override existing slug on create" do
    tag = create(:tag, name: "Machine Learning", slug: "custom-slug")
    assert_equal "custom-slug", tag.slug
  end

  test "alphabetical scope orders by name" do
    zebra = create(:tag, name: "Zebra")
    apple = create(:tag, name: "Apple")
    mango = create(:tag, name: "Mango")

    result = Tag.alphabetical
    assert_equal [apple, mango, zebra], result.to_a
  end

  test "popular scope orders by agent_tag count descending" do
    popular_tag = create(:tag, name: "Popular")
    unpopular_tag = create(:tag, name: "Unpopular")

    3.times { create(:agent_tag, tag: popular_tag) }
    1.times { create(:agent_tag, tag: unpopular_tag) }

    result = Tag.popular
    assert_equal popular_tag, result.first
  end

  test "has many agents through agent_tags" do
    tag = create(:tag)
    agent1 = create(:agent)
    agent2 = create(:agent)
    create(:agent_tag, tag: tag, agent: agent1)
    create(:agent_tag, tag: tag, agent: agent2)

    assert_equal 2, tag.agents.count
    assert_includes tag.agents, agent1
    assert_includes tag.agents, agent2
  end

  test "destroying tag destroys associated agent_tags" do
    tag = create(:tag)
    create(:agent_tag, tag: tag)

    assert_difference "AgentTag.count", -1 do
      tag.destroy
    end
  end
end
