# spec/factories/chat_sessions.rb
FactoryBot.define do
  factory :chat_session, class: 'AiConsultation::ChatSession' do
    association :user, factory: :user
    title { Faker::Lorem.sentence }
    context_type { %w[general excel_analysis knowledge_base].sample }

    trait :with_excel_context do
      context_type { 'excel_analysis' }
      context_id { create(:excel_file, :completed).id }
    end

    trait :with_messages do
      after(:create) do |chat_session|
        create_list(:chat_message, 5, chat_session: chat_session)
      end
    end

    trait :active do
      last_activity_at { Time.current }
    end

    trait :archived do
      archived { true }
      archived_at { 1.month.ago }
    end
  end

  factory :chat_message, class: 'AiConsultation::ChatMessage' do
    association :chat_session
    role { %w[user assistant].sample }
    content { Faker::Lorem.paragraph }

    trait :user_message do
      role { 'user' }
    end

    trait :assistant_message do
      role { 'assistant' }
      tokens_used { rand(50..500) }
      model_version { 'gpt-4' }
    end

    trait :with_function_call do
      function_name { 'analyze_data' }
      function_args do
        {
          data_type: 'excel',
          operation: 'statistical_analysis'
        }
      end
    end
  end
end
