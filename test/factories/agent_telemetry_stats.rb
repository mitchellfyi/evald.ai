# frozen_string_literal: true

FactoryBot.define do
  factory :agent_telemetry_stat do
    association :agent
    period_start { 1.hour.ago }
    period_end { Time.current }
    total_events { 100 }
    success_rate { 95.0 }
    avg_duration_ms { 250.0 }
    p95_duration_ms { 800.0 }
    total_tokens { 5000 }
    error_types { {} }

    trait :hourly do
      period_start { 1.hour.ago }
      period_end { Time.current }
    end

    trait :daily do
      period_start { 1.day.ago }
      period_end { Time.current }
    end

    trait :weekly do
      period_start { 1.week.ago }
      period_end { Time.current }
    end
  end
end
