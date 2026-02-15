# frozen_string_literal: true

require "test_helper"

class AiModelsSyncJobTest < ActiveSupport::TestCase
  def setup
    # Mock at adapter level for reliability
    AiModels::Adapters::OpenrouterAdapter.any_instance.stubs(:fetch_models).returns([])
    AiModels::Adapters::LitellmAdapter.any_instance.stubs(:fetch_models).returns([])
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
end
