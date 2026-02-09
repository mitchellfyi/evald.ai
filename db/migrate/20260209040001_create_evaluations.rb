class CreateEvaluations < ActiveRecord::Migration[8.0]
  def change
    create_table :evaluations do |t|
      t.references :agent, null: false, foreign_key: true
      t.string :tier, null: false # tier0, tier1, tier2
      t.string :status, default: 'pending' # pending, running, completed, failed
      
      # Computed scores
      t.decimal :score, precision: 5, scale: 2
      t.jsonb :scores, default: {} # detailed breakdown
      
      # Metadata
      t.string :version # agent version evaluated
      t.string :commit_sha # git commit if applicable
      t.jsonb :raw_data, default: {} # raw evaluation data
      t.text :notes
      
      t.datetime :started_at
      t.datetime :completed_at
      
      t.timestamps
    end
    
    add_index :evaluations, :tier
    add_index :evaluations, :status
    add_index :evaluations, [:agent_id, :tier, :created_at]
  end
end
