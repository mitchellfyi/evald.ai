# frozen_string_literal: true

require "test_helper"

class AiModelsSyncJobTest < ActiveSupport::TestCase
  def setup
    stub_external_apis
  end

  test "performs full sync by default" do
    assert_nothing_raised do
      AiModelsSyncJob.perform_now(mode: :full)
    end
  end

  test "performs quick sync when specified" do
    assert_nothing_raised do
      AiModelsSyncJob.perform_now(mode: :quick)
    end
  end

  test "performs provider-specific sync when provider specified" do
    assert_nothing_raised do
      AiModelsSyncJob.perform_now(mode: :full, provider: "OpenAI")
    end
  end

  test "job is enqueued to default queue" do
    assert_equal "default", AiModelsSyncJob.new.queue_name
  end

  private

  def stub_external_apis
    stub_request(:get, "https://openrouter.ai/api/v1/models")
      .to_return(
        status: 200,
        body: { "data" => [] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    stub_request(:get, "https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json")
      .to_return(
        status: 200,
        body: {}.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end
end
