# frozen_string_literal: true

module Tier0
  class LicenseClarityAnalyzer
    # OSI-approved licenses grouped by category
    # See: https://opensource.org/licenses/
    PERMISSIVE_LICENSES = %w[
      mit
      apache-2.0
      bsd-2-clause
      bsd-3-clause
      isc
      unlicense
      0bsd
      wtfpl
      zlib
    ].freeze

    COPYLEFT_LICENSES = %w[
      gpl-2.0
      gpl-3.0
      lgpl-2.1
      lgpl-3.0
      agpl-3.0
      mpl-2.0
      eupl-1.2
    ].freeze

    WEAK_COPYLEFT_LICENSES = %w[
      lgpl-2.1
      lgpl-3.0
      mpl-2.0
    ].freeze

    # All OSI-approved (permissive + copyleft)
    OSI_APPROVED = (PERMISSIVE_LICENSES + COPYLEFT_LICENSES).uniq.freeze

    def initialize(agent)
      @agent = agent
      @client = GithubClient.new
      parse_repo_url
    end

    def analyze
      license_info = fetch_license

      {
        has_license: license_info.present?,
        license_key: license_info&.dig("license", "key"),
        license_name: license_info&.dig("license", "name"),
        spdx_id: license_info&.dig("license", "spdx_id"),
        is_osi_approved: osi_approved?(license_info),
        license_category: categorize_license(license_info),
        score: calculate_score(license_info)
      }
    end

    private

    def fetch_license
      # Use GitHub's license detection API
      uri = URI("https://api.github.com/repos/#{@owner}/#{@repo}/license")
      request = Net::HTTP::Get.new(uri)
      token = Rails.application.credentials.dig(:github, :token) || ENV["GITHUB_TOKEN"]
      request["Authorization"] = "Bearer #{token}" if token
      request["Accept"] = "application/vnd.github.v3+json"

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }

      return nil unless response.code.to_i == 200

      JSON.parse(response.body)
    rescue StandardError
      nil
    end

    def osi_approved?(license_info)
      return false unless license_info

      key = license_info.dig("license", "key")
      return false unless key

      OSI_APPROVED.include?(key.downcase)
    end

    def categorize_license(license_info)
      return :none unless license_info

      key = license_info.dig("license", "key")&.downcase
      return :unknown unless key

      if PERMISSIVE_LICENSES.include?(key)
        :permissive
      elsif WEAK_COPYLEFT_LICENSES.include?(key)
        :weak_copyleft
      elsif COPYLEFT_LICENSES.include?(key)
        :copyleft
      elsif key == "other"
        :custom
      else
        :unknown
      end
    end

    def calculate_score(license_info)
      return 0 unless license_info

      key = license_info.dig("license", "key")&.downcase
      return 10 unless key  # Has license file but unrecognized

      case categorize_license(license_info)
      when :permissive
        # Popular permissive licenses get highest scores
        case key
        when "mit" then 100
        when "apache-2.0" then 95
        when "bsd-3-clause", "bsd-2-clause" then 90
        when "isc", "unlicense", "0bsd" then 85
        else 80
        end
      when :weak_copyleft
        # LGPL, MPL - permissive for library usage
        75
      when :copyleft
        # GPL, AGPL - more restrictive
        60
      when :custom
        # Custom/other license - needs manual review
        30
      when :unknown
        # Has license but not in our known list
        40
      else
        0
      end
    end

    def parse_repo_url
      match = @agent.repo_url.match(%r{github\.com/([^/]+)/([^/]+)})
      @owner, @repo = match[1], match[2].sub(/\.git$/, "") if match
    end
  end
end
