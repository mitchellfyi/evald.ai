# frozen_string_literal: true

require "test_helper"

class WebhookDeliveryTest < ActiveSupport::TestCase
  test "factory creates valid webhook_delivery" do
    delivery = build(:webhook_delivery)
    assert delivery.valid?
  end

  test "requires event_type" do
    delivery = build(:webhook_delivery, event_type: nil)
    refute delivery.valid?
    assert_includes delivery.errors[:event_type], "can't be blank"
  end

  test "status must be valid" do
    delivery = build(:webhook_delivery, status: "invalid")
    refute delivery.valid?
    assert_includes delivery.errors[:status], "is not included in the list"
  end

  test "accepts valid status values" do
    WebhookDelivery::STATUSES.each do |status|
      delivery = build(:webhook_delivery, status: status)
      assert delivery.valid?, "#{status} should be valid"
    end
  end

  test "pending scope returns only pending deliveries" do
    pending = create(:webhook_delivery, status: "pending")
    delivered = create(:webhook_delivery, :delivered)

    result = WebhookDelivery.pending
    assert_includes result, pending
    refute_includes result, delivered
  end

  test "failed scope returns only failed deliveries" do
    failed = create(:webhook_delivery, :failed)
    pending = create(:webhook_delivery, status: "pending")

    result = WebhookDelivery.failed
    assert_includes result, failed
    refute_includes result, pending
  end

  test "retryable scope returns pending deliveries with past next_retry_at" do
    retryable = create(:webhook_delivery, :retryable)
    future_retry = create(:webhook_delivery, status: "pending", attempt_count: 1, next_retry_at: 1.hour.from_now)
    delivered = create(:webhook_delivery, :delivered)

    result = WebhookDelivery.retryable
    assert_includes result, retryable
    refute_includes result, future_retry
    refute_includes result, delivered
  end

  test "recent scope orders by created_at descending" do
    old = create(:webhook_delivery, created_at: 2.hours.ago)
    recent = create(:webhook_delivery, created_at: 1.minute.ago)

    result = WebhookDelivery.recent
    assert_equal recent, result.first
  end

  test "mark_delivering! updates status and increments attempt_count" do
    delivery = create(:webhook_delivery, status: "pending", attempt_count: 0)
    delivery.mark_delivering!

    assert_equal "delivering", delivery.status
    assert_equal 1, delivery.attempt_count
  end

  test "mark_delivered! updates status, response, and records success on endpoint" do
    delivery = create(:webhook_delivery, status: "delivering", attempt_count: 1)
    delivery.mark_delivered!(response_code: 200, response_body: "OK")

    assert_equal "delivered", delivery.status
    assert_equal 200, delivery.response_code
    assert_equal "OK", delivery.response_body
    assert_not_nil delivery.delivered_at
    assert_nil delivery.error_message
  end

  test "mark_failed! sets to pending with retry when under max attempts" do
    delivery = create(:webhook_delivery, status: "delivering", attempt_count: 1)
    delivery.mark_failed!(error: "Connection refused", response_code: 500)

    assert_equal "pending", delivery.status
    assert_equal "Connection refused", delivery.error_message
    assert_equal 500, delivery.response_code
    assert_not_nil delivery.next_retry_at
  end

  test "mark_failed! sets to failed when at max attempts" do
    delivery = create(:webhook_delivery, status: "delivering", attempt_count: WebhookDelivery::MAX_ATTEMPTS)
    delivery.mark_failed!(error: "Connection refused")

    assert_equal "failed", delivery.status
  end

  test "retryable? returns true when pending and under max attempts" do
    delivery = build(:webhook_delivery, status: "pending", attempt_count: 2)
    assert delivery.retryable?
  end

  test "retryable? returns false when at max attempts" do
    delivery = build(:webhook_delivery, status: "pending", attempt_count: WebhookDelivery::MAX_ATTEMPTS)
    refute delivery.retryable?
  end

  test "retryable? returns false when not pending" do
    delivery = build(:webhook_delivery, status: "delivered", attempt_count: 1)
    refute delivery.retryable?
  end

  test "belongs to webhook_endpoint" do
    endpoint = create(:webhook_endpoint)
    delivery = create(:webhook_delivery, webhook_endpoint: endpoint)
    assert_equal endpoint, delivery.webhook_endpoint
  end
end
