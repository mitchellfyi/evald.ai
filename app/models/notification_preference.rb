# frozen_string_literal: true
class NotificationPreference < ApplicationRecord
  belongs_to :user
  belongs_to :agent

  validates :user_id, uniqueness: { scope: :agent_id }
end
