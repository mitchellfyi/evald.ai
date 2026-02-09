FactoryBot.define do
  factory :api_key do
    association :user
    name { "Test API Key" }

    trait :expired do
      expires_at { 1.day.ago }
    end

    trait :with_ip_restriction do
      allowed_ips { ["192.168.1.0/24", "10.0.0.1"] }
    end
  end
end
