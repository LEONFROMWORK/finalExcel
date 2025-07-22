# spec/factories/users.rb
FactoryBot.define do
  factory :user, class: 'Authentication::User' do
    email { Faker::Internet.unique.email }
    password { 'password123' }
    password_confirmation { 'password123' }
    name { Faker::Name.name }
    role { :user }
    confirmed_at { Time.current }

    trait :admin do
      role { :admin }
    end

    trait :unconfirmed do
      confirmed_at { nil }
    end

    trait :with_google_oauth do
      provider { 'google_oauth2' }
      uid { Faker::Number.unique.number(digits: 21).to_s }
    end

    trait :with_excel_files do
      after(:create) do |user|
        create_list(:excel_file, 3, user: user)
      end
    end

    trait :with_chat_sessions do
      after(:create) do |user|
        create_list(:chat_session, 2, user: user)
      end
    end
  end
end
