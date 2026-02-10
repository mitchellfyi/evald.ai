# frozen_string_literal: true

class Tag < ApplicationRecord
  has_many :agent_tags, dependent: :destroy
  has_many :agents, through: :agent_tags

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }

  before_validation :generate_slug, on: :create

  scope :alphabetical, -> { order(:name) }
  scope :popular, -> { left_joins(:agent_tags).group(:id).order("COUNT(agent_tags.id) DESC") }

  private

  def generate_slug
    self.slug ||= name&.parameterize
  end
end
