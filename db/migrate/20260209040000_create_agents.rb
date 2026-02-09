class CreateAgents < ActiveRecord::Migration[8.0]
  def change
    create_table :agents do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :repo_url
      t.string :website_url
      t.string :description
      t.string :category # coding, research, workflow, etc.
      t.string :builder_name
      t.string :builder_url
      
      # Evaled Score (computed)
      t.decimal :score, precision: 5, scale: 2
      t.decimal :score_at_eval, precision: 5, scale: 2
      t.datetime :last_verified_at
      t.string :decay_rate, default: 'standard' # standard, slow, fast
      t.datetime :next_eval_scheduled_at
      
      # Tier 0 scores (passive signals)
      t.decimal :tier0_repo_health, precision: 5, scale: 2
      t.decimal :tier0_bus_factor, precision: 5, scale: 2
      t.decimal :tier0_dependency_risk, precision: 5, scale: 2
      t.decimal :tier0_documentation, precision: 5, scale: 2
      t.decimal :tier0_community, precision: 5, scale: 2
      t.decimal :tier0_license, precision: 5, scale: 2
      t.decimal :tier0_maintenance, precision: 5, scale: 2
      
      # Tier 1 scores (task evals)
      t.decimal :tier1_completion_rate, precision: 5, scale: 4
      t.decimal :tier1_accuracy, precision: 5, scale: 4
      t.decimal :tier1_cost_efficiency, precision: 5, scale: 4
      t.decimal :tier1_scope_discipline, precision: 5, scale: 4
      t.decimal :tier1_safety, precision: 5, scale: 4
      
      # Claim status
      t.string :claim_status, default: 'unclaimed' # unclaimed, claimed, verified
      t.references :claimed_by_user, foreign_key: { to_table: :users }, null: true
      t.datetime :claimed_at
      
      # Metadata
      t.jsonb :metadata, default: {}
      t.boolean :featured, default: false
      t.boolean :published, default: true
      
      t.timestamps
    end
    
    add_index :agents, :slug, unique: true
    add_index :agents, :name
    add_index :agents, :category
    add_index :agents, :score
    add_index :agents, :featured
    add_index :agents, :published
  end
end
