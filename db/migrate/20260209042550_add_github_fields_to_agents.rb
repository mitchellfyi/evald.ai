class AddGithubFieldsToAgents < ActiveRecord::Migration[8.1]
  def change
    add_column :agents, :github_id, :integer
    add_index :agents, :github_id, unique: true
    add_column :agents, :owner, :string
    add_column :agents, :stars, :integer
    add_column :agents, :language, :string
    add_column :agents, :github_last_updated_at, :datetime
  end
end
