# frozen_string_literal: true
class AgentInteraction < ApplicationRecord
  belongs_to :reporter_agent, class_name: "Agent"
  belongs_to :target_agent, class_name: "Agent"

  validates :interaction_type, presence: true
  validates :outcome, presence: true

  INTERACTION_TYPES = %w[delegation collaboration query verification task_execution].freeze

  scope :for_target, ->(agent) { where(target_agent: agent) }
  scope :for_reporter, ->(agent) { where(reporter_agent: agent) }
  scope :successful, -> { where(success: true) }
  scope :recent, -> { where("created_at > ?", 90.days.ago) }
end
