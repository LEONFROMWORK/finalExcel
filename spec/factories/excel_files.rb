# spec/factories/excel_files.rb
FactoryBot.define do
  factory :excel_file, class: 'ExcelAnalysis::ExcelFile' do
    association :user, factory: :user
    filename { "#{Faker::Lorem.word}.xlsx" }
    file_size { rand(100_000..5_000_000) }
    file_url { "https://storage.example.com/#{SecureRandom.uuid}/#{filename}" }
    status { :pending }

    trait :processing do
      status { :processing }
    end

    trait :completed do
      status { :completed }
      processed_at { Time.current }
    end

    trait :failed do
      status { :failed }
      error_message { "Processing failed: #{Faker::Lorem.sentence}" }
    end

    trait :with_analysis_result do
      after(:create) do |excel_file|
        create(:analysis_result, excel_file: excel_file)
      end
    end
  end

  factory :analysis_result, class: 'ExcelAnalysis::AnalysisResult' do
    association :excel_file
    status { :completed }
    summary { Faker::Lorem.paragraph }
    insights do
      {
        total_rows: rand(100..10000),
        total_columns: rand(5..50),
        data_types: %w[numeric text date boolean],
        missing_values: rand(0..100),
        statistical_summary: {
          mean: rand(0.0..100.0).round(2),
          median: rand(0.0..100.0).round(2),
          std_dev: rand(0.0..50.0).round(2)
        }
      }
    end

    trait :with_ai_analysis do
      ai_analysis do
        {
          key_findings: Array.new(3) { Faker::Lorem.sentence },
          recommendations: Array.new(2) { Faker::Lorem.sentence },
          data_quality_score: rand(70..100)
        }
      end
    end
  end
end
