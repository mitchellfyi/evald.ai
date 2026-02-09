# frozen_string_literal: true
require "test_helper"

class AgentInteractionTest < ActiveSupport::TestCase
  setup do
    @reporter = create(:agent, :published, :with_score, slug: "reporter-agent")
    @target = create(:agent, :published, :with_score, slug: "target-agent")
  end

  test "valid interaction" do
    interaction = AgentInteraction.new(
      reporter_agent: @reporter,
      target_agent: @target,
      interaction_type: "delegation",
      outcome: "Completed successfully",
      success: true
    )
    assert interaction.valid?
  end

  test "requires interaction_type" do
    interaction = AgentInteraction.new(
      reporter_agent: @reporter,
      target_agent: @target,
      outcome: "Completed",
      success: true
    )
    assert_not interaction.valid?
    assert interaction.errors[:interaction_type].any?
  end

  test "requires outcome" do
    interaction = AgentInteraction.new(
      reporter_agent: @reporter,
      target_agent: @target,
      interaction_type: "delegation",
      success: true
    )
    assert_not interaction.valid?
    assert interaction.errors[:outcome].any?
  end

  test "scopes work correctly" do
    create(:agent_interaction, reporter_agent: @reporter, target_agent: @target, success: true)
    create(:agent_interaction, reporter_agent: @target, target_agent: @reporter, success: false)

    assert_equal 1, AgentInteraction.for_target(@target).count
    assert_equal 1, AgentInteraction.for_reporter(@reporter).count
    assert_equal 1, AgentInteraction.successful.count
  end
end
