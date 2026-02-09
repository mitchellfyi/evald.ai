# frozen_string_literal: true
class AddDomainScoresToAgents < ActiveRecord::Migration[8.1]
  def change
    # Domain-specific scores (0-100 scale)
    add_column :agents, :coding_score, :decimal, precision: 5, scale: 2
    add_column :agents, :research_score, :decimal, precision: 5, scale: 2
    add_column :agents, :workflow_score, :decimal, precision: 5, scale: 2

    # Domain confidence (eval counts)
    add_column :agents, :coding_evals_count, :integer, default: 0
    add_column :agents, :research_evals_count, :integer, default: 0
    add_column :agents, :workflow_evals_count, :integer, default: 0

    # Agent's target domains (declared or detected)
    add_column :agents, :target_domains, :string, array: true, default: []
    add_column :agents, :primary_domain, :string

    # Index for domain filtering
    add_index :agents, :primary_domain
    add_index :agents, :target_domains, using: :gin
  end
end
