# frozen_string_literal: true
class CreateAgentInteractions < ActiveRecord::Migration[8.1]
  def change
    create_table :agent_interactions do |t|
      t.references :reporter_agent, null: false, foreign_key: { to_table: :agents }
      t.references :target_agent, null: false, foreign_key: { to_table: :agents }
      t.string :interaction_type, null: false
      t.string :outcome, null: false
      t.boolean :success, null: false, default: false
      t.text :notes
      t.decimal :reporter_score_at_time, precision: 5, scale: 2
      t.decimal :target_score_at_time, precision: 5, scale: 2

      t.timestamps
    end

    add_index :agent_interactions, [:reporter_agent_id, :target_agent_id], name: "idx_interactions_reporter_target"
    add_index :agent_interactions, :interaction_type
  end
end
