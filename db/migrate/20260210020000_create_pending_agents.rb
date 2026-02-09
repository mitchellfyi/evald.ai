# frozen_string_literal: true

class CreatePendingAgents < ActiveRecord::Migration[8.1]
  def change
    create_table :pending_agents do |t|
      t.string :name, null: false
      t.string :github_url, null: false
      t.text :description
      t.string :owner
      t.integer :stars
      t.string :language
      t.string :license
      t.jsonb :topics, default: []
      t.integer :confidence_score
      t.string :status, default: "pending", null: false
      t.text :rejection_reason
      t.datetime :discovered_at
      t.references :reviewed_by, foreign_key: { to_table: :users }
      t.datetime :reviewed_at
      t.timestamps
    end

    add_index :pending_agents, :github_url, unique: true
    add_index :pending_agents, :status
    add_index :pending_agents, :confidence_score
  end
end
