# frozen_string_literal: true
class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :timeoutable, :trackable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :lockable,
         :omniauthable,
         lock_strategy: :failed_attempts, unlock_strategy: :time,
         maximum_attempts: 5, unlock_in: 1.hour,
         omniauth_providers: [:github]

  rolify
  has_many :claimed_agents, class_name: "Agent", foreign_key: :claimed_by_user_id
  has_many :api_keys, dependent: :destroy
  has_many :claim_requests, dependent: :destroy
  has_many :notification_preferences, dependent: :destroy

  validates :email, presence: true, uniqueness: true

  def admin?
    admin == true
  end

  def self.from_omniauth(auth)
    github_uid = auth.uid.to_s
    email = auth.info.email || (auth.info.nickname && "#{auth.info.nickname}@github.example.com")

    user = where(github_uid: github_uid).first_or_initialize

    # Link GitHub identity to existing account with same email
    if user.new_record? && email.present?
      existing_user = find_by(email: email)
      user = existing_user if existing_user
    end

    user.github_uid = github_uid
    user.github_username = auth.info.nickname
    user.email = email if email.present?
    user.name = auth.info.name
    user.avatar_url = auth.info.image
    user.password = Devise.friendly_token[0, 20] if user.new_record? && user.encrypted_password.blank?

    user.save
    user
  end
end
