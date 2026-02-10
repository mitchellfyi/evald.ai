# frozen_string_literal: true

require "test_helper"

class SecurityCertificationTest < ActiveSupport::TestCase
  test "factory creates valid security_certification" do
    cert = build(:security_certification)
    assert cert.valid?
  end

  test "requires certification_type" do
    cert = build(:security_certification, certification_type: nil)
    refute cert.valid?
    assert_includes cert.errors[:certification_type], "can't be blank"
  end

  test "certification_type must be valid" do
    cert = build(:security_certification, certification_type: "invalid")
    refute cert.valid?
    assert_includes cert.errors[:certification_type], "is not included in the list"
  end

  test "accepts valid certification_type values" do
    SecurityCertification::CERTIFICATION_TYPES.each do |type|
      cert = build(:security_certification, certification_type: type)
      assert cert.valid?, "#{type} should be valid"
    end
  end

  test "requires level" do
    cert = build(:security_certification, level: nil)
    refute cert.valid?
    assert_includes cert.errors[:level], "can't be blank"
  end

  test "level must be valid" do
    cert = build(:security_certification, level: "invalid")
    refute cert.valid?
    assert_includes cert.errors[:level], "is not included in the list"
  end

  test "accepts valid level values" do
    SecurityCertification::LEVELS.each do |level|
      cert = build(:security_certification, level: level)
      assert cert.valid?, "#{level} should be valid"
    end
  end

  test "requires issued_at" do
    cert = build(:security_certification, issued_at: nil)
    refute cert.valid?
    assert_includes cert.errors[:issued_at], "can't be blank"
  end

  test "active scope returns certs that have not expired" do
    active = create(:security_certification, expires_at: 1.year.from_now)
    expired = create(:security_certification, :expired)
    no_expiry = create(:security_certification, expires_at: nil)

    result = SecurityCertification.active
    assert_includes result, active
    assert_includes result, no_expiry
    refute_includes result, expired
  end

  test "by_type scope filters by certification_type" do
    safety = create(:security_certification, certification_type: "safety")
    security = create(:security_certification, certification_type: "security")

    result = SecurityCertification.by_type("safety")
    assert_includes result, safety
    refute_includes result, security
  end

  test "active? returns true when expires_at is nil" do
    cert = build(:security_certification, expires_at: nil)
    assert cert.active?
  end

  test "active? returns true when expires_at is in the future" do
    cert = build(:security_certification, expires_at: 1.year.from_now)
    assert cert.active?
  end

  test "active? returns false when expires_at is in the past" do
    cert = build(:security_certification, :expired)
    refute cert.active?
  end

  test "level_rank returns correct numeric rank" do
    assert_equal 0, build(:security_certification, level: "bronze").level_rank
    assert_equal 1, build(:security_certification, :silver).level_rank
    assert_equal 2, build(:security_certification, :gold).level_rank
    assert_equal 3, build(:security_certification, :platinum).level_rank
  end

  test "belongs to agent" do
    agent = create(:agent)
    cert = create(:security_certification, agent: agent)
    assert_equal agent, cert.agent
  end
end
