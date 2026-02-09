# frozen_string_literal: true

require "test_helper"

class CertificationServiceTest < ActiveSupport::TestCase
  setup do
    @agent = create(:agent)
    @service = CertificationService.new(@agent)
  end

  # check_eligibility tests
  test "check_eligibility returns not eligible for unknown certification type" do
    result = @service.check_eligibility("unknown", "bronze")

    assert_not result[:eligible]
    assert_includes result[:reason], "Unknown certification"
  end

  test "check_eligibility returns not eligible for unknown level" do
    result = @service.check_eligibility("safety", "diamond")

    assert_not result[:eligible]
  end

  test "check_eligibility returns not eligible when safety score too low for bronze" do
    # No safety score means 0
    result = @service.check_eligibility("safety", "bronze")

    assert_not result[:eligible]
    assert_includes result[:reason], "Safety score too low"
  end

  test "check_eligibility returns eligible for bronze when safety score >= 70" do
    safety_score = create(:safety_score, agent: @agent, overall_score: 75)

    result = @service.check_eligibility("safety", "bronze")

    assert result[:eligible]
  end

  test "check_eligibility returns not eligible for silver when no audit" do
    create(:safety_score, agent: @agent, overall_score: 85)

    result = @service.check_eligibility("safety", "silver")

    assert_not result[:eligible]
    assert_includes result[:reason], "audit required"
  end

  test "check_eligibility returns not eligible for gold when score too low" do
    create(:safety_score, agent: @agent, overall_score: 85)

    result = @service.check_eligibility("safety", "gold")

    assert_not result[:eligible]
    assert_includes result[:reason], "Safety score too low"
  end

  test "check_eligibility returns not eligible for platinum due to manual review" do
    create(:safety_score, agent: @agent, overall_score: 98)
    # Even with high score, platinum requires manual review
    result = @service.check_eligibility("safety", "platinum")

    # Will fail either on audit or manual review
    assert_not result[:eligible]
  end

  # REQUIREMENTS constant tests
  test "REQUIREMENTS has safety certification type" do
    assert CertificationService::REQUIREMENTS.key?("safety")
  end

  test "REQUIREMENTS has all levels for safety" do
    levels = CertificationService::REQUIREMENTS["safety"]

    assert levels.key?("bronze")
    assert levels.key?("silver")
    assert levels.key?("gold")
    assert levels.key?("platinum")
  end

  test "bronze requirements are lowest" do
    bronze = CertificationService::REQUIREMENTS["safety"]["bronze"]

    assert_equal 70, bronze[:min_tier2_score]
    assert_nil bronze[:requires_audit]
  end

  test "platinum requirements are highest" do
    platinum = CertificationService::REQUIREMENTS["safety"]["platinum"]

    assert_equal 95, platinum[:min_tier2_score]
    assert platinum[:requires_audit]
    assert platinum[:manual_review]
  end

  # issue_certification tests
  test "issue_certification raises when not eligible" do
    assert_raises RuntimeError do
      @service.issue_certification("safety", "bronze")
    end
  end

  test "issue_certification creates SecurityCertification when eligible" do
    create(:safety_score, agent: @agent, overall_score: 75)

    assert_difference -> { SecurityCertification.count }, 1 do
      @service.issue_certification("safety", "bronze")
    end
  end

  test "issue_certification sets correct attributes" do
    create(:safety_score, agent: @agent, overall_score: 75)

    cert = @service.issue_certification("safety", "bronze")

    assert_equal @agent.id, cert.agent_id
    assert_equal "safety", cert.certification_type
    assert_equal "bronze", cert.level
    assert_equal "evald.ai", cert.issuer
    assert cert.issued_at.present?
    assert cert.expires_at.present?
  end

  test "issue_certification sets expires_at to 1 year from now" do
    create(:safety_score, agent: @agent, overall_score: 75)

    freeze_time do
      cert = @service.issue_certification("safety", "bronze")
      expected_expiry = 1.year.from_now

      assert_in_delta expected_expiry.to_i, cert.expires_at.to_i, 1
    end
  end
end
