class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :lockable,
         lock_strategy: :failed_attempts, unlock_strategy: :time,
         maximum_attempts: 5, unlock_in: 1.hour

  rolify
  has_many :claimed_agents, class_name: 'Agent', foreign_key: :claimed_by_user_id
  has_many :api_keys, dependent: :destroy

  validates :email, presence: true, uniqueness: true

  def admin?
    admin == true
  end
end
