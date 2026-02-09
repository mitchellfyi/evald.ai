class CreateClaimRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :claim_requests do |t|
      t.references :agent, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :status
      t.jsonb :github_verification
      t.datetime :requested_at
      t.datetime :verified_at

      t.timestamps
    end
  end
end
