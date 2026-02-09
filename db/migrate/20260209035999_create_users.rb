class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :name
      t.string :github_username
      t.string :github_uid
      t.string :avatar_url
      t.boolean :admin, default: false
      
      t.timestamps
    end
    
    add_index :users, :email, unique: true
    add_index :users, :github_uid, unique: true
  end
end
