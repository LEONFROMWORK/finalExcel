FactoryBot.define do
  factory :vba_usage_pattern do
    error_pattern { "MyString" }
    solution_used { "MyText" }
    was_helpful { false }
    user_id { nil }
    confidence_score { 1.5 }
    feedback_text { "MyText" }
  end
end
