class CreateCertifications < ActiveRecord::Migration[8.1]
  def change
    create_table :certifications do |t|
      t.references :agent, null: false, foreign_key: true
      t.integer :tier
      t.integer :status
      t.datetime :applied_at
      t.datetime :reviewed_at
      t.datetime :expires_at
      t.text :reviewer_notes

      t.timestamps
    end
  end
end
