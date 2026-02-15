# frozen_string_literal: true

namespace :ai_models do
  desc "Sync all AI models from external sources"
  task sync: :environment do
    puts "Starting full AI models sync..."
    stats = AiModels::SyncService.new.sync_all
    puts "Sync complete!"
    puts "  Created: #{stats[:created]}"
    puts "  Updated: #{stats[:updated]}"
    puts "  Skipped: #{stats[:skipped]}"
    puts "  Errors: #{stats[:errors]}"
  end

  desc "Quick sync (pricing only) for AI models"
  task quick_sync: :environment do
    puts "Starting quick sync (pricing only)..."
    stats = AiModels::SyncService.new.quick_sync
    puts "Quick sync complete!"
    puts "  Updated: #{stats[:updated]}"
    puts "  Skipped: #{stats[:skipped]}"
    puts "  Errors: #{stats[:errors]}"
  end

  desc "Sync AI models for a specific provider"
  task :sync_provider, [:provider] => :environment do |_t, args|
    provider = args[:provider]
    unless AiModel::PROVIDERS.include?(provider)
      puts "Invalid provider: #{provider}"
      puts "Valid providers: #{AiModel::PROVIDERS.join(', ')}"
      exit 1
    end

    puts "Syncing models for #{provider}..."
    stats = AiModels::SyncService.new.sync_provider(provider)
    puts "Provider sync complete!"
    puts "  Created: #{stats[:created]}"
    puts "  Updated: #{stats[:updated]}"
    puts "  Skipped: #{stats[:skipped]}"
    puts "  Errors: #{stats[:errors]}"
  end

  desc "List pending model changes that need review"
  task pending_reviews: :environment do
    changes = AiModelChange.needs_review.includes(:ai_model).recent.limit(20)

    if changes.empty?
      puts "No changes pending review."
    else
      puts "Changes pending review (#{changes.count}):"
      changes.each do |change|
        puts "  - #{change.summary} (#{change.source}, confidence: #{change.confidence || 'N/A'})"
      end
    end
  end

  desc "Approve all pending changes"
  task approve_all: :environment do
    count = AiModelChange.unreviewed.update_all(reviewed: true)
    puts "Approved #{count} pending changes."
  end

  desc "Show sync statistics"
  task stats: :environment do
    total = AiModel.count
    synced = AiModel.where.not(last_synced_at: nil).count
    stale = AiModel.stale(24).count
    changes_today = AiModelChange.where("created_at > ?", 24.hours.ago).count

    puts "AI Models Sync Statistics"
    puts "========================="
    puts "Total models: #{total}"
    puts "Synced models: #{synced}"
    puts "Stale (>24h): #{stale}"
    puts "Changes (24h): #{changes_today}"

    puts "\nBy provider:"
    AiModel::PROVIDERS.each do |provider|
      count = AiModel.by_provider(provider).count
      puts "  #{provider}: #{count}" if count > 0
    end

    puts "\nBy source:"
    AiModel.group(:sync_source).count.each do |source, count|
      puts "  #{source || 'manual'}: #{count}"
    end
  end
end
