# frozen_string_literal: true

class AgentTag < ApplicationRecord
  belongs_to :agent
  belongs_to :tag

  validates :agent_id, uniqueness: { scope: :tag_id }
end
