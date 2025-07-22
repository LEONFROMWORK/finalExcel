# spec/factories/qa_pairs.rb
FactoryBot.define do
  factory :qa_pair, class: 'KnowledgeBase::QaPair' do
    association :user, factory: :user
    question { Faker::Lorem.question }
    answer { Faker::Lorem.paragraph(sentence_count: 3) }
    category { %w[general technical analysis methodology].sample }
    is_public { true }

    trait :private do
      is_public { false }
    end

    trait :with_embedding do
      question_embedding { Array.new(1536) { rand(-1.0..1.0) } }
    end

    trait :verified do
      verified { true }
      verified_at { Time.current }
      verified_by { association :user, factory: [ :user, :admin ] }
    end

    trait :from_excel_analysis do
      source_type { 'excel_analysis' }
      source_id { create(:excel_file, :completed).id }
      metadata do
        {
          sheet_name: Faker::Lorem.word,
          cell_reference: "A#{rand(1..100)}",
          confidence_score: rand(0.7..1.0).round(2)
        }
      end
    end
  end
end
