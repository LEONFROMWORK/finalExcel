FactoryBot.define do
  factory :vector_db_status do
    source_type { "MyString" }
    source_id { 1 }
    status { "MyString" }
    progress { 1 }
    total_items { 1 }
    processed_items { 1 }
    failed_items { 1 }
    error_messages { "" }
    metadata { "" }
    started_at { "2025-07-21 22:56:09" }
    completed_at { "2025-07-21 22:56:09" }
  end
end
