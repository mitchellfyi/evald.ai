# frozen_string_literal: true

require "test_helper"

class AgentScoreMailerTest < ActionMailer::TestCase
  setup do
    @user = create(:user, email: "owner@example.com")
    @agent = create(:agent, :claimed, name: "TestAgent", claimed_by_user: @user)
    @agent_score = create(:agent_score, agent: @agent, overall_score: 85.0, score_at_eval: 100.0)
    @retention = 72.5
    @threshold = 80
  end

  test "decay_warning sends email to user" do
    email = AgentScoreMailer.decay_warning(@user, @agent, @agent_score, @retention, @threshold)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ "owner@example.com" ], email.to
    assert_equal [ "notifications@evaled.ai" ], email.from
  end

  test "decay_warning includes agent name in subject" do
    email = AgentScoreMailer.decay_warning(@user, @agent, @agent_score, @retention, @threshold)

    assert_includes email.subject, "TestAgent"
    assert_includes email.subject, "80% threshold"
  end

  test "decay_warning html body includes all required information" do
    email = AgentScoreMailer.decay_warning(@user, @agent, @agent_score, @retention, @threshold)

    html_body = email.html_part.body.to_s

    # Agent name
    assert_includes html_body, "TestAgent"

    # Current score (decayed)
    assert_match(/\d+\.\d/, html_body)

    # Original score
    assert_includes html_body, "100.0"

    # Decay percentage
    assert_includes html_body, "27.5%"

    # Retention percentage
    assert_includes html_body, "72.5%"

    # Threshold
    assert_includes html_body, "80%"

    # Re-evaluate link (use actual agent slug from factory)
    assert_match(/href=.*agents.*#{@agent.slug}/i, html_body)
  end

  test "decay_warning text body includes all required information" do
    email = AgentScoreMailer.decay_warning(@user, @agent, @agent_score, @retention, @threshold)

    text_body = email.text_part.body.to_s

    # Agent name
    assert_includes text_body, "TestAgent"

    # Original score
    assert_includes text_body, "100.0"

    # Decay percentage
    assert_includes text_body, "27.5%"

    # Retention percentage
    assert_includes text_body, "72.5%"

    # Threshold
    assert_includes text_body, "80"
  end

  test "decay_warning includes link to agent profile" do
    email = AgentScoreMailer.decay_warning(@user, @agent, @agent_score, @retention, @threshold)

    text_body = email.text_part.body.to_s

    # Should contain a URL to the agent
    assert_match %r{/agents/}, text_body
  end

  test "decay_warning with different thresholds" do
    [ 90, 80, 70, 60, 50 ].each do |threshold|
      email = AgentScoreMailer.decay_warning(@user, @agent, @agent_score, threshold - 5, threshold)

      assert_includes email.subject, "#{threshold}% threshold"
    end
  end

  test "decay_warning handles edge case scores" do
    @agent_score.update!(overall_score: 0.5, score_at_eval: 100.0)

    email = AgentScoreMailer.decay_warning(@user, @agent, @agent_score, 0.5, 50)

    assert_nothing_raised do
      email.deliver_now
    end
  end
end
