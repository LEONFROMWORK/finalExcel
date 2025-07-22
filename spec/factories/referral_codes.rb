FactoryBot.define do
  factory :referral_code do
    user { nil }
    code { "MyString" }
    usage_count { 1 }
    max_uses { 1 }
    credits_per_signup { "9.99" }
    credits_per_purchase { "9.99" }
    expires_at { "2025-07-21 23:04:12" }
    is_active { false }
  end
end
