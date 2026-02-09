require "test_helper"

class ApiKeyTest < ActiveSupport::TestCase
  test "factory creates valid api_key" do
    api_key = build(:api_key)
    assert api_key.valid?
  end

  test "requires name" do
    api_key = build(:api_key, name: nil)
    refute api_key.valid?
    assert_includes api_key.errors[:name], "can't be blank"
  end

  test "requires user" do
    api_key = build(:api_key, user: nil)
    refute api_key.valid?
  end

  test "generates token on create" do
    user = create(:user)
    api_key = ApiKey.create!(name: "Test Key", user: user)

    assert_not_nil api_key.token
    assert_equal 64, api_key.token.length  # SecureRandom.hex(32) = 64 chars
  end

  test "token is unique" do
    api_key1 = create(:api_key)
    api_key2 = build(:api_key, token: api_key1.token)

    refute api_key2.valid?
    assert_includes api_key2.errors[:token], "has already been taken"
  end

  test "expired? returns false when no expiry set" do
    api_key = build(:api_key, expires_at: nil)
    refute api_key.expired?
  end

  test "expired? returns false when expiry is in future" do
    api_key = build(:api_key, expires_at: 1.day.from_now)
    refute api_key.expired?
  end

  test "expired? returns true when expiry is in past" do
    api_key = build(:api_key, :expired)
    assert api_key.expired?
  end

  test "active scope excludes expired keys" do
    user = create(:user)
    active_key = create(:api_key, user: user, expires_at: 1.day.from_now)
    expired_key = create(:api_key, :expired, user: user)
    no_expiry_key = create(:api_key, user: user, expires_at: nil)

    result = ApiKey.active
    assert_includes result, active_key
    assert_includes result, no_expiry_key
    refute_includes result, expired_key
  end

  test "touch_last_used! updates last_used_at" do
    api_key = create(:api_key)
    assert_nil api_key.last_used_at

    api_key.touch_last_used!
    api_key.reload

    assert_not_nil api_key.last_used_at
    assert_in_delta Time.current, api_key.last_used_at, 2.seconds
  end

  test "ip_allowed? returns true when no restrictions" do
    api_key = build(:api_key, allowed_ips: nil)
    assert api_key.ip_allowed?("192.168.1.100")

    api_key = build(:api_key, allowed_ips: [])
    assert api_key.ip_allowed?("192.168.1.100")
  end

  test "ip_allowed? checks against allowed_ips" do
    api_key = build(:api_key, :with_ip_restriction)

    # IP in allowed range
    assert api_key.ip_allowed?("192.168.1.100")
    assert api_key.ip_allowed?("10.0.0.1")

    # IP not in allowed range
    refute api_key.ip_allowed?("172.16.0.1")
  end
end
