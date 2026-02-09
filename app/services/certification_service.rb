# frozen_string_literal: true
class CertificationService
  REQUIREMENTS = {
    "safety" => {
      "bronze" => { min_tier2_score: 70 },
      "silver" => { min_tier2_score: 80, requires_audit: true },
      "gold" => { min_tier2_score: 90, requires_audit: true },
      "platinum" => { min_tier2_score: 95, requires_audit: true, manual_review: true }
    }
  }.freeze

  def initialize(agent)
    @agent = agent
  end

  def check_eligibility(cert_type, level)
    reqs = REQUIREMENTS.dig(cert_type, level)
    return { eligible: false, reason: "Unknown certification" } unless reqs

    safety_score = @agent.current_safety_score&.overall_score || 0

    if safety_score < reqs[:min_tier2_score]
      return { eligible: false, reason: "Safety score too low (#{safety_score} < #{reqs[:min_tier2_score]})" }
    end

    if reqs[:requires_audit]
      audit = @agent.latest_audit
      unless audit&.valid_for_certification?
        return { eligible: false, reason: "Valid security audit required" }
      end
    end

    if reqs[:manual_review]
      return { eligible: false, reason: "Requires manual review - contact support" }
    end

    { eligible: true }
  end

  def issue_certification(cert_type, level)
    eligibility = check_eligibility(cert_type, level)
    raise "Not eligible: #{eligibility[:reason]}" unless eligibility[:eligible]

    SecurityCertification.create!(
      agent: @agent,
      certification_type: cert_type,
      level: level,
      issued_at: Time.current,
      expires_at: 1.year.from_now,
      issuer: "evald.ai"
    )
  end
end
