# frozen_string_literal: true
class CreateNotificationPreferences < ActiveRecord::Migration[8.1]
  def change
    create_table :notification_preferences do |t|
      t.references :user, null: false, foreign_key: true
      t.references :agent, null: false, foreign_key: true
      t.boolean :score_changes, default: true
      t.boolean :new_eval_results, default: true
      t.boolean :comparison_mentions, default: false
      t.boolean :email_enabled, default: true

      t.timestamps
    end

    add_index :notification_preferences, [:user_id, :agent_id], unique: true
  end
end
