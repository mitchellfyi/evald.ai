# frozen_string_literal: true

class CreateAiModels < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_models do |t|
      # Identity
      t.string :name, null: false
      t.string :slug, null: false
      t.string :provider, null: false
      t.string :family
      t.date :release_date

      # Links
      t.string :website_url
      t.string :docs_url
      t.string :github_url
      t.string :api_reference_url
      t.string :changelog_url

      # Pricing (stored as decimals for precision)
      t.decimal :input_per_1m_tokens, precision: 10, scale: 4
      t.decimal :output_per_1m_tokens, precision: 10, scale: 4
      t.decimal :cached_input_per_1m_tokens, precision: 10, scale: 4
      t.decimal :batch_discount_percentage, precision: 5, scale: 2
      t.string :free_tier_description

      # Capabilities
      t.integer :context_window
      t.integer :max_output_tokens
      t.boolean :supports_vision, default: false
      t.boolean :supports_function_calling, default: false
      t.boolean :supports_json_mode, default: false
      t.boolean :supports_streaming, default: false
      t.boolean :supports_fine_tuning, default: false
      t.boolean :supports_embedding, default: false

      # Benchmarks
      t.jsonb :benchmarks, default: {}

      # Content
      t.text :cliff_notes
      t.string :key_features, default: [], array: true
      t.string :best_for, default: [], array: true
      t.string :limitations, default: [], array: true

      # API identifier (e.g., "claude-3-5-sonnet-20241022")
      t.string :api_model_id

      # Meta
      t.string :status, default: "active"
      t.boolean :published, default: true
      t.datetime :last_updated_at

      t.timestamps
    end

    add_index :ai_models, :slug, unique: true
    add_index :ai_models, :provider
    add_index :ai_models, :family
    add_index :ai_models, :status
    add_index :ai_models, :published
    add_index :ai_models, [:provider, :family]
  end
end
