# frozen_string_literal: true

class Rack::Attack
  ### Configure Cache ###
  # Use Rails cache (defaults to memory store in development)
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  ### Throttle Strategies ###

  # Throttle all requests by IP (100 req/min)
  throttle("req/ip", limit: 100, period: 1.minute) do |req|
    req.ip unless req.path.start_with?("/assets")
  end

  # Throttle API requests by API key (60 req/min)
  throttle("api/key", limit: 60, period: 1.minute) do |req|
    if req.path.start_with?("/api")
      req.env["HTTP_AUTHORIZATION"]&.split(" ")&.last ||
        req.params["api_key"] ||
        req.ip
    end
  end

  # Throttle login attempts by IP (5 attempts/20 seconds)
  throttle("logins/ip", limit: 5, period: 20.seconds) do |req|
    if req.path == "/users/sign_in" && req.post?
      req.ip
    end
  end

  # Throttle login attempts by email (5 attempts/minute)
  throttle("logins/email", limit: 5, period: 1.minute) do |req|
    if req.path == "/users/sign_in" && req.post?
      req.params.dig("user", "email")&.downcase&.strip
    end
  end

  ### Blocklists ###

  # Block suspicious requests (SQL injection patterns)
  blocklist("block/sql_injection") do |req|
    sql_injection_patterns = [
      /(\%27)|(\')|(\-\-)|(\%23)|(#)/i,
      /((\%3D)|(=))[^\n]*((\%27)|(\')|(\-\-)|(\%3B)|(;))/i,
      /\w*((\%27)|(\'))((\%6F)|o|(\%4F))((\%72)|r|(\%52))/i,
      /((\%27)|(\'))union/i,
      /exec(\s|\+)+(s|x)p\w+/i,
      /UNION(\s+)SELECT/i,
      /SELECT.*FROM.*WHERE/i
    ]

    query = req.query_string.to_s + req.path.to_s
    sql_injection_patterns.any? { |pattern| query.match?(pattern) }
  end

  # Block requests with suspicious user agents
  blocklist("block/bad_ua") do |req|
    bad_user_agents = [
      /sqlmap/i,
      /nikto/i,
      /havij/i,
      /acunetix/i,
      /w3af/i
    ]
    ua = req.user_agent.to_s
    bad_user_agents.any? { |pattern| ua.match?(pattern) }
  end

  ### Safelists ###

  # Allow localhost in development
  safelist("allow/localhost") do |req|
    "127.0.0.1" == req.ip || "::1" == req.ip
  end

  ### Custom Responses ###

  # Return 429 Too Many Requests with retry info
  self.throttled_responder = lambda do |request|
    match_data = request.env["rack.attack.match_data"]
    now = match_data[:epoch_time]
    retry_after = match_data[:period] - (now % match_data[:period])

    [
      429,
      {
        "Content-Type" => "application/json",
        "Retry-After" => retry_after.to_s
      },
      [{ error: "Rate limit exceeded. Retry in #{retry_after} seconds." }.to_json]
    ]
  end

  # Return 403 Forbidden for blocked requests
  self.blocklisted_responder = lambda do |request|
    [
      403,
      { "Content-Type" => "application/json" },
      [{ error: "Forbidden" }.to_json]
    ]
  end
end

# Log throttled and blocked requests in development
if Rails.env.development?
  ActiveSupport::Notifications.subscribe("throttle.rack_attack") do |_name, _start, _finish, _id, payload|
    Rails.logger.warn "[Rack::Attack] Throttled #{payload[:request].ip}"
  end

  ActiveSupport::Notifications.subscribe("blocklist.rack_attack") do |_name, _start, _finish, _id, payload|
    Rails.logger.warn "[Rack::Attack] Blocked #{payload[:request].ip}"
  end
end
