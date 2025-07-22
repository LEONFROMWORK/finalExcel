FactoryBot.define do
  factory :referral_reward do
    referrer_id { 1 }
    referred_id { 1 }
    referral_code { nil }
    reward_type { "MyString" }
    credits_amount { "9.99" }
    status { "MyString" }
    rewarded_at { "2025-07-21 23:04:26" }
    metadata { "" }
  end
end
