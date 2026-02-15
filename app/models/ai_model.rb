# frozen_string_literal: true

class AiModel < ApplicationRecord
  PROVIDERS = %w[OpenAI Anthropic Google Meta Mistral Cohere xAI DeepSeek Alibaba Amazon].freeze
  STATUSES = %w[active deprecated preview].freeze
  PRICING_FIELDS = %w[input_per_1m_tokens output_per_1m_tokens cached_input_per_1m_tokens batch_discount_percentage].freeze
  CAPABILITY_FIELDS = %w[supports_vision supports_function_calling supports_json_mode supports_streaming
                         supports_fine_tuning supports_embedding context_window max_output_tokens].freeze
  SYNCABLE_FIELDS = (PRICING_FIELDS + CAPABILITY_FIELDS + %w[status]).freeze

  has_many :sync_changes, class_name: "AiModelChange", dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }
  validates :provider, presence: true, inclusion: { in: PROVIDERS }
  validates :status, inclusion: { in: STATUSES }
  validates :input_per_1m_tokens, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :output_per_1m_tokens, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :context_window, numericality: { greater_than: 0 }, allow_nil: true
  validates :max_output_tokens, numericality: { greater_than: 0 }, allow_nil: true
  validates :website_url, :docs_url, :github_url, :api_reference_url, :changelog_url,
            allow_blank: true,
            format: {
              with: URI::DEFAULT_PARSER.make_regexp(%w[http https]),
              message: "must be a valid HTTP/HTTPS URL"
            }

  before_validation :generate_slug, on: :create

  scope :published, -> { where(published: true) }
  scope :active, -> { where(status: "active") }
  scope :by_provider, ->(provider) { where(provider: provider) }
  scope :by_family, ->(family) { where(family: family) }
  scope :syncable, -> { where(sync_enabled: true) }
  scope :stale, ->(hours = 24) { where("last_synced_at IS NULL OR last_synced_at < ?", hours.hours.ago) }

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
      "#{(context_window / 1_000.0).to_i}K"
    else
      context_window.to_s
    end
  end

  def formatted_max_output
    return nil unless max_output_tokens

    if max_output_tokens >= 1_000
      "#{(max_output_tokens / 1_000.0).to_i}K"
    else
      max_output_tokens.to_s
    end
  end

  # Returns a hash of changes between current values and new data
  def diff_with(new_data)
    changes = {}
    SYNCABLE_FIELDS.each do |field|
      current_value = read_attribute(field)
      new_value = new_data[field.to_sym] || new_data[field]
      next if new_value.nil?

      # Compare with type coercion for numeric fields
      current_comparable = current_value.is_a?(BigDecimal) ? current_value.to_f : current_value
      new_comparable = new_value.is_a?(BigDecimal) ? new_value.to_f : new_value

      if current_comparable != new_comparable
        changes[field] = { old: current_value, new: new_value }
      end
    end
    changes
  end

  # Apply changes and record them
  def apply_sync_update!(new_data, source:, confidence: nil)
    diff = diff_with(new_data)
    return false if diff.empty?

    old_values = diff.transform_values { |v| v[:old] }
    new_values = diff.transform_values { |v| v[:new] }

    change_type = determine_change_type(diff)

    transaction do
      diff.each do |field, values|
        write_attribute(field, values[:new])
      end
      self.last_synced_at = Time.current
      self.sync_source = source
      save!

      sync_changes.create!(
        change_type: change_type,
        old_values: old_values,
        new_values: new_values,
        source: source,
        confidence: confidence
      )
    end

    true
  end

  private

  def generate_slug
    self.slug ||= name&.parameterize
  end

  def determine_change_type(diff)
    pricing_changed = (diff.keys & PRICING_FIELDS).any?
    capability_changed = (diff.keys & CAPABILITY_FIELDS).any?

    if diff.key?("status") && diff["status"][:new] == "deprecated"
      "deprecated"
    elsif pricing_changed
      "pricing_change"
    elsif capability_changed
      "capability_change"
    else
      "updated"
    end
  end
end
