# frozen_string_literal: true

class SecurityScanJob < ApplicationJob
  queue_as :default

  def perform(agent_id = nil)
    if agent_id
      agent = Agent.find(agent_id)
      scan_agent(agent)
    else
      scan_all_agents
    end
  end

  private

  def scan_agent(agent)
    scanner = Tier4::VulnerabilityScanner.new
    scanner.scan(agent)
    Rails.logger.info "[SecurityScan] Completed scan for agent: #{agent.slug}"
  rescue StandardError => e
    Rails.logger.error "[SecurityScan] Failed to scan agent #{agent.slug}: #{e.message}"
  end

  def scan_all_agents
    Agent.where.not(repo_url: nil).find_each do |agent|
      scan_agent(agent)
    end
  end
end
