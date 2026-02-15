# frozen_string_literal: true

module AiModels
  class SyncService
    attr_reader :adapters, :logger, :stats

    def initialize(adapters: nil, logger: Rails.logger)
      @logger = logger
      @adapters = adapters || default_adapters
      @stats = { created: 0, updated: 0, skipped: 0, errors: 0 }
    end

    # Sync all models from all adapters
    def sync_all
      logger.info("[AiModels::SyncService] Starting full sync")

      adapters.each do |adapter|
        sync_from_adapter(adapter)
      end

      logger.info("[AiModels::SyncService] Sync complete: #{stats}")
      stats
    end

    # Sync only models from a specific provider
    def sync_provider(provider)
      logger.info("[AiModels::SyncService] Syncing provider: #{provider}")

      adapters.each do |adapter|
        models = adapter.fetch_models.select { |m| m[:provider] == provider }
        sync_models(models, source: adapter.source)
      end

      logger.info("[AiModels::SyncService] Provider sync complete: #{stats}")
      stats
    end

    # Quick sync: only update pricing and status
    def quick_sync
      logger.info("[AiModels::SyncService] Starting quick sync (pricing only)")

      # Use OpenRouter for quick pricing updates as it's comprehensive
      adapter = Adapters::OpenrouterAdapter.new(logger: logger)
      models = adapter.fetch_models

      models.each do |model_data|
        update_pricing_only(model_data, source: adapter.source)
      end

      logger.info("[AiModels::SyncService] Quick sync complete: #{stats}")
      stats
    end

    private

    def default_adapters
      [
        Adapters::OpenrouterAdapter.new(logger: logger),
        Adapters::LitellmAdapter.new(logger: logger)
      ]
    end

    def sync_from_adapter(adapter)
      logger.info("[AiModels::SyncService] Fetching from #{adapter.class.name}")

      models = adapter.fetch_models
      sync_models(models, source: adapter.source)
    rescue StandardError => e
      logger.error("[AiModels::SyncService] Error syncing from #{adapter.class.name}: #{e.message}")
      @stats[:errors] += 1
    end

    def sync_models(models, source:)
      models.each do |model_data|
        sync_model(model_data, source: source)
      end
    end

    def sync_model(model_data, source:)
      external_id = model_data[:external_id]
      return unless external_id

      # Try to find existing model by external_id or api_model_id
      existing = find_existing_model(model_data)

      if existing
        update_existing_model(existing, model_data, source: source)
      else
        create_new_model(model_data, source: source)
      end
    rescue StandardError => e
      logger.error("[AiModels::SyncService] Error syncing model #{model_data[:name]}: #{e.message}")
      @stats[:errors] += 1
    end

    def find_existing_model(model_data)
      AiModel.find_by(external_id: model_data[:external_id]) ||
        AiModel.find_by(api_model_id: model_data[:api_model_id]) ||
        AiModel.find_by(slug: model_data[:name]&.parameterize)
    end

    def update_existing_model(model, model_data, source:)
      # Don't overwrite if we have a more authoritative source
      if model.sync_source && source_priority(model.sync_source) > source_priority(source)
        @stats[:skipped] += 1
        return
      end

      if model.apply_sync_update!(model_data, source: source)
        @stats[:updated] += 1
        logger.info("[AiModels::SyncService] Updated: #{model.name}")
      else
        @stats[:skipped] += 1
      end
    end

    def create_new_model(model_data, source:)
      # Only create models we're confident about
      return unless model_data[:provider] && model_data[:name]

      slug = model_data[:name].parameterize
      return if AiModel.exists?(slug: slug)

      model = AiModel.new(
        name: model_data[:name],
        slug: slug,
        provider: model_data[:provider],
        api_model_id: model_data[:api_model_id],
        external_id: model_data[:external_id],
        context_window: model_data[:context_window],
        max_output_tokens: model_data[:max_output_tokens],
        input_per_1m_tokens: model_data[:input_per_1m_tokens],
        output_per_1m_tokens: model_data[:output_per_1m_tokens],
        cached_input_per_1m_tokens: model_data[:cached_input_per_1m_tokens],
        supports_vision: model_data[:supports_vision] || false,
        supports_function_calling: model_data[:supports_function_calling] || false,
        supports_json_mode: model_data[:supports_json_mode] || false,
        supports_streaming: model_data[:supports_streaming] || true,
        status: model_data[:status] || "active",
        sync_source: source,
        last_synced_at: Time.current,
        published: false # New models start unpublished for review
      )

      if model.save
        model.sync_changes.create!(
          change_type: "created",
          new_values: model.attributes.slice(*AiModel::SYNCABLE_FIELDS),
          source: source
        )
        @stats[:created] += 1
        logger.info("[AiModels::SyncService] Created: #{model.name} (unpublished)")
      else
        logger.warn("[AiModels::SyncService] Failed to create #{model_data[:name]}: #{model.errors.full_messages}")
        @stats[:errors] += 1
      end
    end

    def update_pricing_only(model_data, source:)
      model = find_existing_model(model_data)
      return unless model

      pricing_data = model_data.slice(:input_per_1m_tokens, :output_per_1m_tokens,
                                       :cached_input_per_1m_tokens, :status)
      model.apply_sync_update!(pricing_data, source: source)
    end

    def source_priority(source)
      # Higher number = more authoritative
      {
        "manual" => 100,
        "openai_api" => 90,
        "anthropic_api" => 90,
        "google_api" => 90,
        "openrouter" => 50,
        "litellm" => 40,
        "ai_extracted" => 20
      }[source] || 0
    end
  end
end
