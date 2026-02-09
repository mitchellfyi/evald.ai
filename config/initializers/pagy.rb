# Pagy configuration - v43+ syntax
# Note: In Pagy v43+, defaults are set via environment or per-call options
# See https://ddnexus.github.io/pagy/docs/how-to/#configure-pagy

# For Pagy v43+, we configure via Pagy.configure if available,
# otherwise settings are applied per-call
if Pagy.respond_to?(:configure)
  Pagy.configure do |config|
    config.limit = 25
    config.overflow = :last_page
  end
end
