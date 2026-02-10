# frozen_string_literal: true

require "test_helper"

class WebhookEndpointTest < ActiveSupport::TestCase
  test "factory creates valid webhook_endpoint" do
    endpoint = build(:webhook_endpoint)
    assert endpoint.valid?
  end

  test "requires url" do
    endpoint = build(:webhook_endpoint, url: nil)
    refute endpoint.valid?
    assert_includes endpoint.errors[:url], "can't be blank"
  end

  test "url must be a valid http(s) URL" do
    endpoint = build(:webhook_endpoint, url: "not-a-url")
    refute endpoint.valid?
    assert_includes endpoint.errors[:url], "is invalid"
  end

  test "accepts valid https URL" do
    endpoint = build(:webhook_endpoint, url: "https://example.com/webhook")
    assert endpoint.valid?
  end

  test "accepts valid http URL" do
    endpoint = build(:webhook_endpoint, url: "http://example.com/webhook")
    assert endpoint.valid?
  end

  test "requires events" do
    endpoint = build(:webhook_endpoint, events: [])
    refute endpoint.valid?
    assert_includes endpoint.errors[:events], "can't be blank"
  end

  test "events must be valid event types" do
    endpoint = build(:webhook_endpoint, events: ["invalid.event"])
    refute endpoint.valid?
    assert_includes endpoint.errors[:events].first, "contains invalid events"
  end

  test "accepts valid event types" do
    WebhookEndpoint::EVENTS.each do |event|
      endpoint = build(:webhook_endpoint, events: [event])
      assert endpoint.valid?, "#{event} should be valid"
    end
  end

  test "active scope returns only enabled endpoints" do
    active = create(:webhook_endpoint, enabled: true)
    disabled = create(:webhook_endpoint, :disabled)

    result = WebhookEndpoint.active
    assert_includes result, active
    refute_includes result, disabled
  end

  test "for_event scope returns active endpoints subscribed to event" do
    score_endpoint = create(:webhook_endpoint, events: ["score.created"])
    safety_endpoint = create(:webhook_endpoint, events: ["safety_score.created"])
    disabled_endpoint = create(:webhook_endpoint, :disabled, events: ["score.created"])

    result = WebhookEndpoint.for_event("score.created")
    assert_includes result, score_endpoint
    refute_includes result, safety_endpoint
    refute_includes result, disabled_endpoint
  end

  test "regenerate_secret! generates a new secret" do
    endpoint = create(:webhook_endpoint)
    old_secret = endpoint.secret
    endpoint.regenerate_secret!

    refute_equal old_secret, endpoint.secret
    assert_equal 64, endpoint.secret.length
  end

  test "record_success! updates last_triggered_at and resets failure_count" do
    endpoint = create(:webhook_endpoint, failure_count: 3)
    endpoint.record_success!

    assert_equal 0, endpoint.failure_count
    assert_not_nil endpoint.last_triggered_at
  end

  test "record_failure! increments failure_count" do
    endpoint = create(:webhook_endpoint, failure_count: 0)
    endpoint.record_failure!

    assert_equal 1, endpoint.failure_count
  end

  test "record_failure! disables endpoint at max failure count" do
    endpoint = create(:webhook_endpoint, failure_count: WebhookEndpoint::MAX_FAILURE_COUNT - 1)
    endpoint.record_failure!

    assert_equal false, endpoint.enabled
    assert_not_nil endpoint.disabled_at
  end

  test "reenable! re-enables a disabled endpoint" do
    endpoint = create(:webhook_endpoint, :disabled, failure_count: 5)
    endpoint.reenable!

    assert_equal true, endpoint.enabled
    assert_nil endpoint.disabled_at
    assert_equal 0, endpoint.failure_count
  end

  test "belongs to agent" do
    agent = create(:agent)
    endpoint = create(:webhook_endpoint, agent: agent)
    assert_equal agent, endpoint.agent
  end

  test "has many webhook_deliveries" do
    endpoint = create(:webhook_endpoint)
    create(:webhook_delivery, webhook_endpoint: endpoint)
    create(:webhook_delivery, webhook_endpoint: endpoint)

    assert_equal 2, endpoint.webhook_deliveries.count
  end

  test "destroying endpoint destroys associated deliveries" do
    endpoint = create(:webhook_endpoint)
    create(:webhook_delivery, webhook_endpoint: endpoint)

    assert_difference "WebhookDelivery.count", -1 do
      endpoint.destroy
    end
  end
end
