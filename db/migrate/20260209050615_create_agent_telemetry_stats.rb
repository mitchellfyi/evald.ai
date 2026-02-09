class CreateAgentTelemetryStats < ActiveRecord::Migration[8.1]
  def change
    create_table :agent_telemetry_stats do |t|
      t.references :agent, null: false, foreign_key: true
      t.datetime :period_start
      t.datetime :period_end
      t.integer :total_events
      t.decimal :success_rate
      t.decimal :avg_duration_ms
      t.decimal :p95_duration_ms
      t.integer :total_tokens
      t.jsonb :error_types

      t.timestamps
    end
  end
end
