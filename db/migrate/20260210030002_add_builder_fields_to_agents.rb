# frozen_string_literal: true
class AddBuilderFieldsToAgents < ActiveRecord::Migration[8.1]
  def change
    add_column :agents, :tagline, :string
    add_column :agents, :use_case, :text
    add_column :agents, :documentation_url, :string
    add_column :agents, :changelog_url, :string
    add_column :agents, :demo_url, :string
  end
end
