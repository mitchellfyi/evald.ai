# frozen_string_literal: true

require "test_helper"

class AgentTagTest < ActiveSupport::TestCase
  test "factory creates valid agent_tag" do
    agent_tag = build(:agent_tag)
    assert agent_tag.valid?
  end

  test "requires agent" do
    agent_tag = build(:agent_tag, agent: nil)
    refute agent_tag.valid?
  end

  test "requires tag" do
    agent_tag = build(:agent_tag, tag: nil)
    refute agent_tag.valid?
  end

  test "enforces uniqueness of agent_id scoped to tag_id" do
    agent_tag = create(:agent_tag)
    duplicate = build(:agent_tag, agent: agent_tag.agent, tag: agent_tag.tag)
    refute duplicate.valid?
    assert_includes duplicate.errors[:agent_id], "has already been taken"
  end

  test "allows same agent with different tags" do
    agent = create(:agent)
    tag1 = create(:tag)
    tag2 = create(:tag)

    create(:agent_tag, agent: agent, tag: tag1)
    agent_tag2 = build(:agent_tag, agent: agent, tag: tag2)
    assert agent_tag2.valid?
  end

  test "allows same tag with different agents" do
    tag = create(:tag)
    agent1 = create(:agent)
    agent2 = create(:agent)

    create(:agent_tag, agent: agent1, tag: tag)
    agent_tag2 = build(:agent_tag, agent: agent2, tag: tag)
    assert agent_tag2.valid?
  end

  test "belongs to agent" do
    agent = create(:agent)
    agent_tag = create(:agent_tag, agent: agent)
    assert_equal agent, agent_tag.agent
  end

  test "belongs to tag" do
    tag = create(:tag)
    agent_tag = create(:agent_tag, tag: tag)
    assert_equal tag, agent_tag.tag
  end
end
