class User < ApplicationRecord
  rolify
  has_many :claimed_agents, class_name: 'Agent', foreign_key: :claimed_by_user_id

  validates :email, presence: true, uniqueness: true

  def admin?
    admin == true
  end
end
