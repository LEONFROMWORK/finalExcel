# spec/factories/data_pipelines.rb
FactoryBot.define do
  factory :data_source, class: 'DataPipeline::DataSource' do
    name { Faker::Company.name }
    source_type { %w[api database file webhook].sample }
    configuration do
      case source_type
      when 'api'
        {
          endpoint: Faker::Internet.url,
          method: 'GET',
          headers: { 'Authorization' => 'Bearer token' },
          polling_interval: 3600
        }
      when 'database'
        {
          adapter: 'postgresql',
          host: 'localhost',
          database: Faker::Lorem.word,
          query: 'SELECT * FROM data'
        }
      when 'file'
        {
          path: "/data/#{Faker::File.file_name}",
          format: %w[csv json xlsx].sample,
          delimiter: ','
        }
      when 'webhook'
        {
          webhook_url: Faker::Internet.url(path: '/webhooks/data'),
          secret: SecureRandom.hex(32)
        }
      end
    end
    active { true }

    trait :inactive do
      active { false }
    end

    trait :with_collection_logs do
      after(:create) do |data_source|
        create_list(:data_collection_log, 3, data_source: data_source)
      end
    end
  end

  factory :workflow, class: 'DataPipeline::Workflow' do
    name { "#{Faker::Lorem.word.capitalize} Workflow" }
    description { Faker::Lorem.paragraph }
    schedule { '0 */6 * * *' } # Every 6 hours
    active { true }

    trait :inactive do
      active { false }
    end

    trait :with_steps do
      after(:create) do |workflow|
        create(:workflow_step, :extract, workflow: workflow, order: 1)
        create(:workflow_step, :transform, workflow: workflow, order: 2)
        create(:workflow_step, :load, workflow: workflow, order: 3)
      end
    end
  end

  factory :workflow_step, class: 'DataPipeline::WorkflowStep' do
    association :workflow
    name { Faker::Lorem.word }
    step_type { %w[extract transform load validate].sample }
    configuration { {} }
    order { 1 }

    trait :extract do
      step_type { 'extract' }
      configuration do
        {
          source_id: create(:data_source).id,
          fields: %w[id name value timestamp]
        }
      end
    end

    trait :transform do
      step_type { 'transform' }
      configuration do
        {
          operations: [
            { type: 'rename', from: 'value', to: 'amount' },
            { type: 'convert', field: 'amount', to: 'float' },
            { type: 'filter', condition: 'amount > 0' }
          ]
        }
      end
    end

    trait :load do
      step_type { 'load' }
      configuration do
        {
          destination: 'knowledge_base',
          mapping: {
            question: 'name',
            answer: 'description'
          }
        }
      end
    end
  end

  factory :data_collection_log, class: 'DataPipeline::DataCollectionLog' do
    association :data_source
    started_at { 1.hour.ago }
    completed_at { Time.current }
    status { :success }
    records_processed { rand(100..10000) }

    trait :failed do
      status { :failed }
      error_message { "Connection timeout: #{Faker::Lorem.sentence}" }
      completed_at { nil }
    end

    trait :processing do
      status { :processing }
      completed_at { nil }
    end
  end
end
