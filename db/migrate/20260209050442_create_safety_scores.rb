class CreateSafetyScores < ActiveRecord::Migration[8.1]
  def change
    create_table :safety_scores do |t|
      t.references :agent, null: false, foreign_key: true
      t.decimal :overall_score
      t.string :badge
      t.jsonb :breakdown

      t.timestamps
    end
  end
end
