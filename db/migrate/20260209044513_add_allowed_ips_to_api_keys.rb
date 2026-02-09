class AddAllowedIpsToApiKeys < ActiveRecord::Migration[8.1]
  def change
    add_column :api_keys, :allowed_ips, :string, array: true, default: []
  end
end
