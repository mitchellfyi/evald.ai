# frozen_string_literal: true

class CreateAiModelChanges < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_model_changes do |t|
      t.references :ai_model, null: false, foreign_key: true
      t.string :change_type, null: false # created, updated, deprecated, pricing_change
      t.jsonb :old_values, default: {}
      t.jsonb :new_values, default: {}
      t.string :source, null: false # openai_api, anthropic_api, openrouter, litellm, manual, ai_extracted
      t.float :confidence # 0.0-1.0 for AI-extracted data
      t.boolean :reviewed, default: false
      t.text :notes

      t.timestamps
    end

    add_index :ai_model_changes, :change_type
    add_index :ai_model_changes, :source
    add_index :ai_model_changes, :reviewed
    add_index :ai_model_changes, :created_at
  end
end
