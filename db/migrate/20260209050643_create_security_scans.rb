class CreateSecurityScans < ActiveRecord::Migration[8.1]
  def change
    create_table :security_scans do |t|
      t.references :agent, null: false, foreign_key: true
      t.string :scan_type
      t.jsonb :findings
      t.jsonb :severity_counts
      t.boolean :passed
      t.datetime :scanned_at

      t.timestamps
    end
  end
end
