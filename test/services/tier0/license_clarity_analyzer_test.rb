# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

module Tier0
  class LicenseClarityAnalyzerTest < ActiveSupport::TestCase
    setup do
      @agent = create(:agent, repo_url: "https://github.com/testowner/testrepo")
      WebMock.enable!
      stub_no_license
    end

    teardown do
      WebMock.disable!
    end

    test "analyze returns hash with expected keys" do
      result = LicenseClarityAnalyzer.new(@agent).analyze

      assert result.key?(:has_license)
      assert result.key?(:license_key)
      assert result.key?(:license_name)
      assert result.key?(:spdx_id)
      assert result.key?(:is_osi_approved)
      assert result.key?(:license_category)
      assert result.key?(:score)
    end

    test "has_license is false when no license" do
      result = LicenseClarityAnalyzer.new(@agent).analyze

      assert_not result[:has_license]
      assert_nil result[:license_key]
      assert_equal 0, result[:score]
    end

    test "detects MIT license correctly" do
      stub_license("mit", "MIT License", "MIT")

      result = LicenseClarityAnalyzer.new(@agent).analyze

      assert result[:has_license]
      assert_equal "mit", result[:license_key]
      assert_equal "MIT License", result[:license_name]
      assert_equal "MIT", result[:spdx_id]
      assert result[:is_osi_approved]
      assert_equal :permissive, result[:license_category]
      assert_equal 100, result[:score]
    end

    test "detects Apache-2.0 license correctly" do
      stub_license("apache-2.0", "Apache License 2.0", "Apache-2.0")

      result = LicenseClarityAnalyzer.new(@agent).analyze

      assert result[:has_license]
      assert_equal "apache-2.0", result[:license_key]
      assert result[:is_osi_approved]
      assert_equal :permissive, result[:license_category]
      assert_equal 95, result[:score]
    end

    test "detects BSD-3-Clause license correctly" do
      stub_license("bsd-3-clause", "BSD 3-Clause License", "BSD-3-Clause")

      result = LicenseClarityAnalyzer.new(@agent).analyze

      assert result[:has_license]
      assert_equal "bsd-3-clause", result[:license_key]
      assert result[:is_osi_approved]
      assert_equal :permissive, result[:license_category]
      assert_equal 90, result[:score]
    end

    test "detects ISC license correctly" do
      stub_license("isc", "ISC License", "ISC")

      result = LicenseClarityAnalyzer.new(@agent).analyze

      assert result[:has_license]
      assert_equal "isc", result[:license_key]
      assert result[:is_osi_approved]
      assert_equal :permissive, result[:license_category]
      assert_equal 85, result[:score]
    end

    test "detects GPL-3.0 license as copyleft" do
      stub_license("gpl-3.0", "GNU General Public License v3.0", "GPL-3.0")

      result = LicenseClarityAnalyzer.new(@agent).analyze

      assert result[:has_license]
      assert_equal "gpl-3.0", result[:license_key]
      assert result[:is_osi_approved]
      assert_equal :copyleft, result[:license_category]
      assert_equal 60, result[:score]
    end

    test "detects AGPL-3.0 license as copyleft" do
      stub_license("agpl-3.0", "GNU Affero General Public License v3.0", "AGPL-3.0")

      result = LicenseClarityAnalyzer.new(@agent).analyze

      assert result[:has_license]
      assert_equal "agpl-3.0", result[:license_key]
      assert result[:is_osi_approved]
      assert_equal :copyleft, result[:license_category]
      assert_equal 60, result[:score]
    end

    test "detects LGPL-3.0 license as weak copyleft" do
      stub_license("lgpl-3.0", "GNU Lesser General Public License v3.0", "LGPL-3.0")

      result = LicenseClarityAnalyzer.new(@agent).analyze

      assert result[:has_license]
      assert_equal "lgpl-3.0", result[:license_key]
      assert result[:is_osi_approved]
      assert_equal :weak_copyleft, result[:license_category]
      assert_equal 75, result[:score]
    end

    test "detects MPL-2.0 license as weak copyleft" do
      stub_license("mpl-2.0", "Mozilla Public License 2.0", "MPL-2.0")

      result = LicenseClarityAnalyzer.new(@agent).analyze

      assert result[:has_license]
      assert_equal "mpl-2.0", result[:license_key]
      assert result[:is_osi_approved]
      assert_equal :weak_copyleft, result[:license_category]
      assert_equal 75, result[:score]
    end

    test "detects custom license with low score" do
      stub_license("other", "Other", "NOASSERTION")

      result = LicenseClarityAnalyzer.new(@agent).analyze

      assert result[:has_license]
      assert_equal "other", result[:license_key]
      assert_not result[:is_osi_approved]
      assert_equal :custom, result[:license_category]
      assert_equal 30, result[:score]
    end

    test "handles unknown license type" do
      stub_license("some-unknown-license", "Some Unknown License", "UNKNOWN")

      result = LicenseClarityAnalyzer.new(@agent).analyze

      assert result[:has_license]
      assert_equal "some-unknown-license", result[:license_key]
      assert_not result[:is_osi_approved]
      assert_equal :unknown, result[:license_category]
      assert_equal 40, result[:score]
    end

    test "unlicense is detected as permissive" do
      stub_license("unlicense", "The Unlicense", "Unlicense")

      result = LicenseClarityAnalyzer.new(@agent).analyze

      assert result[:has_license]
      assert_equal "unlicense", result[:license_key]
      assert result[:is_osi_approved]
      assert_equal :permissive, result[:license_category]
      assert_equal 85, result[:score]
    end

    test "handles API errors gracefully" do
      stub_request(:get, %r{api.github.com/repos/.*/license})
        .to_return(status: 500, body: { message: "Internal Server Error" }.to_json)

      result = LicenseClarityAnalyzer.new(@agent).analyze

      assert_not result[:has_license]
      assert_nil result[:license_key]
      assert_equal 0, result[:score]
    end

    test "handles timeout gracefully" do
      stub_request(:get, %r{api.github.com/repos/.*/license})
        .to_timeout

      result = LicenseClarityAnalyzer.new(@agent).analyze

      assert_not result[:has_license]
      assert_nil result[:license_key]
      assert_equal 0, result[:score]
    end

    private

    def stub_license(key, name, spdx_id)
      stub_request(:get, %r{api.github.com/repos/.*/license})
        .to_return(
          status: 200,
          body: {
            name: "LICENSE",
            path: "LICENSE",
            license: {
              key: key,
              name: name,
              spdx_id: spdx_id,
              url: "https://api.github.com/licenses/#{key}"
            }
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    def stub_no_license
      stub_request(:get, %r{api.github.com/repos/.*/license})
        .to_return(status: 404, body: { message: "Not Found" }.to_json)
    end
  end
end
