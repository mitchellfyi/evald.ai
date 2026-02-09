# frozen_string_literal: true

class GithubTrendingMonitorJob < ApplicationJob
  queue_as :discovery

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform
    service = GithubTrendingService.new
    candidates = service.discover

    Rails.logger.info("GitHub Trending Monitor: discovered #{candidates.compact.size} new candidates")
  end
end
