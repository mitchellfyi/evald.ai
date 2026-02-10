# frozen_string_literal: true

class CreateTagsAndAgentTags < ActiveRecord::Migration[8.0]
  def change
    create_table :tags do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :color, default: "#6366f1"
      t.text :description

      t.timestamps
    end

    add_index :tags, :name, unique: true
    add_index :tags, :slug, unique: true

    create_table :agent_tags do |t|
      t.references :agent, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true

      t.timestamps
    end

    add_index :agent_tags, [:agent_id, :tag_id], unique: true
  end
end
