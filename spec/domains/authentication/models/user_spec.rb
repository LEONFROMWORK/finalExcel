# spec/domains/authentication/models/user_spec.rb
require 'rails_helper'

RSpec.describe Authentication::User, type: :model do
  describe 'validations' do
    subject { build(:user) }

    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).case_insensitive }
    it { should validate_presence_of(:password).on(:create) }
    it { should validate_length_of(:password).is_at_least(6) }
  end

  describe 'associations' do
    it { should have_many(:excel_files).class_name('ExcelAnalysis::ExcelFile').dependent(:destroy) }
    it { should have_many(:qa_pairs).class_name('KnowledgeBase::QaPair').dependent(:destroy) }
    it { should have_many(:chat_sessions).class_name('AiConsultation::ChatSession').dependent(:destroy) }
  end

  describe 'enums' do
    it { should define_enum_for(:role).with_values(user: 0, admin: 1) }
  end

  describe 'devise modules' do
    it { should have_db_column(:encrypted_password) }
    it { should have_db_column(:reset_password_token) }
    it { should have_db_column(:remember_created_at) }
    it { should have_db_column(:confirmation_token) }
    it { should have_db_column(:provider) }
    it { should have_db_column(:uid) }
  end

  describe '#admin?' do
    it 'returns true for admin users' do
      user = build(:user, :admin)
      expect(user.admin?).to be true
    end

    it 'returns false for regular users' do
      user = build(:user)
      expect(user.admin?).to be false
    end
  end

  describe '#from_omniauth' do
    let(:auth_hash) do
      OmniAuth::AuthHash.new({
        provider: 'google_oauth2',
        uid: '123456789',
        info: {
          email: 'test@example.com',
          name: 'Test User'
        }
      })
    end

    context 'when user does not exist' do
      it 'creates a new user' do
        expect {
          Authentication::User.from_omniauth(auth_hash)
        }.to change(Authentication::User, :count).by(1)
      end

      it 'sets user attributes correctly' do
        user = Authentication::User.from_omniauth(auth_hash)
        expect(user.email).to eq('test@example.com')
        expect(user.name).to eq('Test User')
        expect(user.provider).to eq('google_oauth2')
        expect(user.uid).to eq('123456789')
      end

      it 'skips confirmation' do
        user = Authentication::User.from_omniauth(auth_hash)
        expect(user).to be_confirmed
      end
    end

    context 'when user exists with same email' do
      let!(:existing_user) { create(:user, email: 'test@example.com') }

      it 'updates provider and uid' do
        user = Authentication::User.from_omniauth(auth_hash)
        expect(user.id).to eq(existing_user.id)
        expect(user.provider).to eq('google_oauth2')
        expect(user.uid).to eq('123456789')
      end
    end

    context 'when OAuth user already exists' do
      let!(:oauth_user) { create(:user, :with_google_oauth, uid: '123456789') }

      it 'returns existing user' do
        user = Authentication::User.from_omniauth(auth_hash)
        expect(user.id).to eq(oauth_user.id)
      end
    end
  end

  describe 'scopes' do
    describe '.admins' do
      let!(:admin1) { create(:user, :admin) }
      let!(:admin2) { create(:user, :admin) }
      let!(:regular_user) { create(:user) }

      it 'returns only admin users' do
        expect(Authentication::User.admins).to contain_exactly(admin1, admin2)
      end
    end

    describe '.confirmed' do
      let!(:confirmed_user) { create(:user) }
      let!(:unconfirmed_user) { create(:user, :unconfirmed) }

      it 'returns only confirmed users' do
        expect(Authentication::User.confirmed).to contain_exactly(confirmed_user)
      end
    end
  end

  describe 'callbacks' do
    describe 'before_destroy' do
      let(:user) { create(:user, :with_excel_files, :with_chat_sessions) }

      it 'destroys associated records' do
        excel_files_count = user.excel_files.count
        chat_sessions_count = user.chat_sessions.count

        expect(excel_files_count).to be > 0
        expect(chat_sessions_count).to be > 0

        user.destroy

        expect(ExcelAnalysis::ExcelFile.count).to eq(0)
        expect(AiConsultation::ChatSession.count).to eq(0)
      end
    end
  end
end
