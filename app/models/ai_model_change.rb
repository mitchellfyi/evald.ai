# frozen_string_literal: true

class AiModelChange < ApplicationRecord
  CHANGE_TYPES = %w[created updated deprecated pricing_change capability_change].freeze
  SOURCES = %w[openai_api anthropic_api google_api openrouter litellm manual ai_extracted].freeze

  belongs_to :ai_model

  validates :change_type, presence: true, inclusion: { in: CHANGE_TYPES }
  validates :source, presence: true, inclusion: { in: SOURCES }
  validates :confidence, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }, allow_nil: true

  scope :unreviewed, -> { where(reviewed: false) }
  scope :reviewed, -> { where(reviewed: true) }
  scope :by_type, ->(type) { where(change_type: type) }
  scope :by_source, ->(source) { where(source: source) }
  scope :recent, -> { order(created_at: :desc) }
  scope :needs_review, -> { unreviewed.where("confidence IS NULL OR confidence < ?", 0.8) }

  def significant_pricing_change?
    return false unless change_type == "pricing_change"

    old_input = old_values["input_per_1m_tokens"]&.to_f
    new_input = new_values["input_per_1m_tokens"]&.to_f
    old_output = old_values["output_per_1m_tokens"]&.to_f
    new_output = new_values["output_per_1m_tokens"]&.to_f

    return false unless old_input && new_input && old_output && new_output

    input_change = ((new_input - old_input) / old_input).abs
    output_change = ((new_output - old_output) / old_output).abs

    input_change > 0.2 || output_change > 0.2
  end

  def summary
    case change_type
    when "created"
      "New model added: #{ai_model.name}"
    when "deprecated"
      "Model deprecated: #{ai_model.name}"
    when "pricing_change"
      "Pricing updated for #{ai_model.name}"
    when "capability_change"
      "Capabilities changed for #{ai_model.name}"
    else
      "Updated: #{ai_model.name}"
    end
  end
end
