# frozen_string_literal: true

class AiModelsSyncJob < ApplicationJob
  queue_as :default

  # Full sync: updates all fields from all sources
  def perform(mode: :full, provider: nil)
    service = AiModels::SyncService.new

    case mode.to_sym
    when :full
      if provider
        service.sync_provider(provider)
      else
        service.sync_all
      end
    when :quick
      service.quick_sync
    else
      Rails.logger.warn("[AiModelsSyncJob] Unknown mode: #{mode}")
    end
  end
end
