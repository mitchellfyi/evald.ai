# frozen_string_literal: true

# CleanupSandboxContainersJob periodically removes stale sandbox containers
# that have exceeded their maximum lifetime. This prevents resource leaks
# from abandoned or stuck evaluation sessions.
#
# Schedule: Run every 15 minutes via cron or Sidekiq scheduler
# Example cron: */15 * * * * bin/rails runner 'CleanupSandboxContainersJob.perform_now'
#
class CleanupSandboxContainersJob < ApplicationJob
  queue_as :maintenance

  # Maximum age for sandbox containers before cleanup (1 hour)
  MAX_CONTAINER_AGE_SECONDS = 3600

  # Retry configuration
  retry_on StandardError, wait: 5.minutes, attempts: 3

  def perform(max_age_seconds: MAX_CONTAINER_AGE_SECONDS)
    Rails.logger.info("[SandboxCleanup] Starting cleanup of stale containers...")

    manager = Tier1::SandboxManager.new
    cleaned_containers = manager.cleanup_stale_containers(max_age_seconds: max_age_seconds)

    if cleaned_containers.any?
      Rails.logger.info(
        "[SandboxCleanup] Cleaned up #{cleaned_containers.size} stale containers: " \
        "#{cleaned_containers.join(', ')}"
      )
    else
      Rails.logger.info("[SandboxCleanup] No stale containers found")
    end

    # Return count for monitoring/testing
    cleaned_containers.size
  rescue Tier1::SandboxManager::ContainerError => e
    Rails.logger.error("[SandboxCleanup] Docker error during cleanup: #{e.message}")
    raise
  rescue StandardError => e
    Rails.logger.error("[SandboxCleanup] Unexpected error: #{e.message}")
    Rails.logger.error(e.backtrace.first(10).join("\n"))
    raise
  end
end
