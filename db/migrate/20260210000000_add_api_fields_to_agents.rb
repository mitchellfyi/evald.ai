# frozen_string_literal: true

class AddApiFieldsToAgents < ActiveRecord::Migration[8.0]
  def change
    add_column :agents, :api_endpoint, :string
    add_column :agents, :api_key, :string
  end
end
