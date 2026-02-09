require "test_helper"

class AgentTest < ActiveSupport::TestCase
  # Validations
  should validate_presence_of(:name)
  should validate_presence_of(:slug)
  should validate_uniqueness_of(:slug)

  # Associations
  should have_many(:evaluations).dependent(:destroy)
  should belong_to(:claimed_by_user).class_name("User").optional

  test "factory creates valid agent" do
    agent = build(:agent)
    assert agent.valid?
  end

  test "generates slug from name on create" do
    agent = Agent.new(name: "My Test Agent")
    agent.valid?
    assert_equal "my-test-agent", agent.slug
  end

  test "slug format validation" do
    agent = build(:agent, slug: "Invalid Slug!")
    refute agent.valid?
    assert_includes agent.errors[:slug], "is invalid"
  end

  test "slug must be unique" do
    create(:agent, slug: "test-agent")
    duplicate = build(:agent, slug: "test-agent")
    refute duplicate.valid?
    assert_includes duplicate.errors[:slug], "has already been taken"
  end

  test "to_param returns slug" do
    agent = build(:agent, slug: "my-agent")
    assert_equal "my-agent", agent.to_param
  end

  test "claimed? returns false for unclaimed agents" do
    agent = build(:agent, claim_status: "unclaimed")
    refute agent.claimed?
  end

  test "claimed? returns true for claimed agents" do
    agent = build(:agent, claim_status: "claimed")
    assert agent.claimed?
  end

  test "verified? returns true only for verified agents" do
    unclaimed = build(:agent, claim_status: "unclaimed")
    claimed = build(:agent, claim_status: "claimed")
    verified = build(:agent, claim_status: "verified")

    refute unclaimed.verified?
    refute claimed.verified?
    assert verified.verified?
  end

  test "badge_color returns appropriate color based on score" do
    assert_equal "brightgreen", build(:agent, score: 95).badge_color
    assert_equal "green", build(:agent, score: 85).badge_color
    assert_equal "yellowgreen", build(:agent, score: 75).badge_color
    assert_equal "yellow", build(:agent, score: 65).badge_color
    assert_equal "orange", build(:agent, score: 55).badge_color
    assert_equal "red", build(:agent, score: 45).badge_color
    assert_equal "gray", build(:agent, score: nil).badge_color
  end

  test "published scope returns only published agents" do
    published = create(:agent, :published)
    unpublished = create(:agent, published: false)

    result = Agent.published
    assert_includes result, published
    refute_includes result, unpublished
  end

  test "featured scope returns only featured agents" do
    featured = create(:agent, :featured)
    not_featured = create(:agent, featured: false)

    result = Agent.featured
    assert_includes result, featured
    refute_includes result, not_featured
  end
end
