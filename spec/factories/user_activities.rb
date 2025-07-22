FactoryBot.define do
  factory :user_activity do
    user { nil }
    action { "MyString" }
    details { "" }
    ip_address { "MyString" }
    user_agent { "MyString" }
    session_id { "MyString" }
    location { "" }
    started_at { "2025-07-21 22:54:49" }
    ended_at { "2025-07-21 22:54:49" }
    credits_used { "9.99" }
    success { false }
  end
end
