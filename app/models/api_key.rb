class ApiKey < ApplicationRecord
  belongs_to :user

  before_create :generate_token

  validates :name, presence: true
  validates :token, uniqueness: true

  scope :active, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }

  def expired?
    expires_at.present? && expires_at < Time.current
  end

  def touch_last_used!
    update_column(:last_used_at, Time.current)
  end

  def ip_allowed?(request_ip)
    return true if allowed_ips.blank?
    allowed_ips.any? { |ip| IPAddr.new(ip).include?(request_ip) }
  end

  private

  def generate_token
    self.token = SecureRandom.hex(32)
  end
end
