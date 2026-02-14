# frozen_string_literal: true

class AiModel < ApplicationRecord
  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }
  validates :provider, presence: true
  validates :input_per_1m_tokens, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :output_per_1m_tokens, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :context_window, numericality: { greater_than: 0 }, allow_nil: true
  validates :max_output_tokens, numericality: { greater_than: 0 }, allow_nil: true

  before_validation :generate_slug, on: :create

  scope :published, -> { where(published: true) }
  scope :active, -> { where(status: "active") }
  scope :by_provider, ->(provider) { where(provider: provider) }
  scope :by_family, ->(family) { where(family: family) }

  PROVIDERS = %w[OpenAI Anthropic Google Meta Mistral Cohere xAI DeepSeek].freeze
  STATUSES = %w[active deprecated preview].freeze

  def to_param
    slug
  end

  def pricing_summary
    parts = []
    parts << "$#{input_per_1m_tokens}/1M input" if input_per_1m_tokens
    parts << "$#{output_per_1m_tokens}/1M output" if output_per_1m_tokens
    parts.join(", ")
  end

  def capabilities_list
    caps = []
    caps << "Vision" if supports_vision
    caps << "Function Calling" if supports_function_calling
    caps << "JSON Mode" if supports_json_mode
    caps << "Streaming" if supports_streaming
    caps << "Fine-tuning" if supports_fine_tuning
    caps << "Embedding" if supports_embedding
    caps
  end

  def formatted_context_window
    return nil unless context_window

    if context_window >= 1_000_000
      "#{(context_window / 1_000_000.0).round(1)}M"
    elsif context_window >= 1_000
      "#{(context_window / 1_000.0).round(0)}K"
    else
      context_window.to_s
    end
  end

  def formatted_max_output
    return nil unless max_output_tokens

    if max_output_tokens >= 1_000
      "#{(max_output_tokens / 1_000.0).round(0)}K"
    else
      max_output_tokens.to_s
    end
  end

  private

  def generate_slug
    self.slug ||= name&.parameterize
  end
end
