# frozen_string_literal: true

class AddAiReviewToPendingAgents < ActiveRecord::Migration[8.1]
  def change
    add_column :pending_agents, :ai_classification, :string  # "agent", "sdk", "library", "tool", "framework", "unknown"
    add_column :pending_agents, :ai_confidence, :float       # 0.0 - 1.0
    add_column :pending_agents, :ai_categories, :jsonb, default: []
    add_column :pending_agents, :ai_description, :text       # AI-generated description
    add_column :pending_agents, :ai_capabilities, :jsonb, default: []
    add_column :pending_agents, :ai_reasoning, :text         # Why it made this classification
    add_column :pending_agents, :ai_reviewed_at, :datetime
    add_column :pending_agents, :is_agent, :boolean          # Final determination
    add_index :pending_agents, :ai_classification
    add_index :pending_agents, :is_agent
  end
end
