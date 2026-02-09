# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require "openssl"

# Service for sending webhook notifications.
# Handles payload formatting, HMAC signing, and HTTP delivery.
class WebhookService
  TIMEOUT_SECONDS = 10
  USER_AGENT = "evald.ai-webhooks/1.0"

  class DeliveryError < StandardError; end

  def initialize(webhook_endpoint)
    @endpoint = webhook_endpoint
  end

  # Queue a webhook delivery for the given event and data
  #
  # @param event_type [String] The event type (e.g., "score.updated")
  # @param data [Hash] The event-specific data
  # @return [WebhookDelivery] The created delivery record
  def queue(event_type, data)
    payload = build_payload(event_type, data)

    delivery = @endpoint.webhook_deliveries.create!(
      event_type: event_type,
      payload: payload,
      status: "pending"
    )

    WebhookDeliveryJob.perform_later(delivery.id)
    delivery
  end

  # Deliver a webhook synchronously (used by the job)
  #
  # @param delivery [WebhookDelivery] The delivery record to process
  def deliver(delivery)
    delivery.mark_delivering!

    uri = URI.parse(@endpoint.url)
    http = build_http_client(uri)

    request = build_request(uri, delivery.payload)
    response = http.request(request)

    handle_response(delivery, response)
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    delivery.mark_failed!(error: "Timeout: #{e.message}")
  rescue StandardError => e
    delivery.mark_failed!(error: "#{e.class}: #{e.message}")
  end

  # Trigger webhooks for all endpoints subscribed to an event
  #
  # @param agent [Agent] The agent whose endpoints to notify
  # @param event_type [String] The event type
  # @param data [Hash] The event data
  def self.trigger(agent, event_type, data)
    agent.webhook_endpoints.for_event(event_type).find_each do |endpoint|
      new(endpoint).queue(event_type, data)
    rescue StandardError => e
      Rails.logger.error("[Webhook] Failed to queue #{event_type} for endpoint #{endpoint.id}: #{e.message}")
    end
  end

  private

  def build_payload(event_type, data)
    {
      id: SecureRandom.uuid,
      event: event_type,
      created_at: Time.current.iso8601,
      data: data
    }
  end

  def build_http_client(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = TIMEOUT_SECONDS
    http.read_timeout = TIMEOUT_SECONDS
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER if http.use_ssl?
    http
  end

  def build_request(uri, payload)
    request = Net::HTTP::Post.new(uri.request_uri)
    request["Content-Type"] = "application/json"
    request["User-Agent"] = USER_AGENT
    request["X-Evald-Event"] = payload[:event]
    request["X-Evald-Delivery"] = payload[:id]

    body = payload.to_json
    request.body = body

    # Add HMAC signature if secret is configured
    if @endpoint.secret.present?
      signature = compute_signature(body)
      request["X-Evald-Signature"] = "sha256=#{signature}"
    end

    request
  end

  def compute_signature(body)
    OpenSSL::HMAC.hexdigest("SHA256", @endpoint.secret, body)
  end

  def handle_response(delivery, response)
    code = response.code.to_i

    if code >= 200 && code < 300
      delivery.mark_delivered!(
        response_code: code,
        response_body: response.body
      )
    else
      delivery.mark_failed!(
        error: "HTTP #{code}",
        response_code: code,
        response_body: response.body
      )
    end
  end
end
