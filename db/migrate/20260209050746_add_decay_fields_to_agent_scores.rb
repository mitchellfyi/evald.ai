class AddDecayFieldsToAgentScores < ActiveRecord::Migration[8.1]
  def change
    add_column :agent_scores, :score_at_eval, :decimal
    add_column :agent_scores, :last_verified_at, :datetime
    add_column :agent_scores, :decay_rate, :string
    add_column :agent_scores, :next_eval_scheduled_at, :datetime
  end
end
