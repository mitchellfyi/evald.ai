# frozen_string_literal: true

class AddSyncFieldsToAiModels < ActiveRecord::Migration[8.0]
  def change
    add_column :ai_models, :last_synced_at, :datetime
    add_column :ai_models, :sync_source, :string # Primary source for this model's data
    add_column :ai_models, :external_id, :string # ID from external source (e.g., openrouter model id)
    add_column :ai_models, :sync_enabled, :boolean, default: true

    add_index :ai_models, :external_id
    add_index :ai_models, :sync_enabled
  end
end
