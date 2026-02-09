# frozen_string_literal: true

require "test_helper"

class GithubTrendingMonitorJobTest < ActiveSupport::TestCase
  test "performs discovery via GithubTrendingService" do
    service = mock("GithubTrendingService")
    service.expects(:discover).returns([])
    GithubTrendingService.expects(:new).returns(service)

    GithubTrendingMonitorJob.perform_now
  end

  test "job is enqueued to discovery queue" do
    assert_equal "discovery", GithubTrendingMonitorJob.new.queue_name
  end
end
