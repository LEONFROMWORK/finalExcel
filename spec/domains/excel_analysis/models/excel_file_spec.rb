# spec/domains/excel_analysis/models/excel_file_spec.rb
require 'rails_helper'

RSpec.describe ExcelAnalysis::ExcelFile, type: :model do
  describe 'validations' do
    subject { build(:excel_file) }

    it { should validate_presence_of(:filename) }
    it { should validate_presence_of(:file_size) }
    it { should validate_numericality_of(:file_size).is_greater_than(0) }
    it { should validate_presence_of(:file_url) }
  end

  describe 'associations' do
    it { should belong_to(:user).class_name('Authentication::User') }
    it { should have_one(:analysis_result).dependent(:destroy) }
  end

  describe 'enums' do
    it { should define_enum_for(:status).with_values(pending: 0, processing: 1, completed: 2, failed: 3) }
  end

  describe 'scopes' do
    describe '.recent' do
      let!(:old_file) { create(:excel_file, created_at: 2.weeks.ago) }
      let!(:recent_file) { create(:excel_file, created_at: 1.hour.ago) }
      let!(:newest_file) { create(:excel_file, created_at: 1.minute.ago) }

      it 'returns files in descending order by creation date' do
        expect(ExcelAnalysis::ExcelFile.recent).to eq([ newest_file, recent_file, old_file ])
      end
    end

    describe '.by_status' do
      let!(:pending_file) { create(:excel_file, status: :pending) }
      let!(:processing_file) { create(:excel_file, status: :processing) }
      let!(:completed_file) { create(:excel_file, status: :completed) }

      it 'filters files by status' do
        expect(ExcelAnalysis::ExcelFile.by_status(:pending)).to contain_exactly(pending_file)
        expect(ExcelAnalysis::ExcelFile.by_status(:processing)).to contain_exactly(processing_file)
        expect(ExcelAnalysis::ExcelFile.by_status(:completed)).to contain_exactly(completed_file)
      end
    end

    describe '.completed' do
      let!(:completed_file1) { create(:excel_file, :completed) }
      let!(:completed_file2) { create(:excel_file, :completed) }
      let!(:pending_file) { create(:excel_file) }

      it 'returns only completed files' do
        expect(ExcelAnalysis::ExcelFile.completed).to contain_exactly(completed_file1, completed_file2)
      end
    end
  end

  describe '#mark_as_processing!' do
    let(:excel_file) { create(:excel_file, status: :pending) }

    it 'changes status to processing' do
      expect {
        excel_file.mark_as_processing!
      }.to change(excel_file, :status).from('pending').to('processing')
    end
  end

  describe '#mark_as_completed!' do
    let(:excel_file) { create(:excel_file, status: :processing) }

    it 'changes status to completed and sets processed_at' do
      Timecop.freeze do
        excel_file.mark_as_completed!

        expect(excel_file.status).to eq('completed')
        expect(excel_file.processed_at).to eq(Time.current)
      end
    end
  end

  describe '#mark_as_failed!' do
    let(:excel_file) { create(:excel_file, status: :processing) }
    let(:error_message) { 'Invalid file format' }

    it 'changes status to failed and sets error message' do
      excel_file.mark_as_failed!(error_message)

      expect(excel_file.status).to eq('failed')
      expect(excel_file.error_message).to eq(error_message)
    end
  end

  describe '#file_extension' do
    it 'returns the file extension' do
      excel_file = build(:excel_file, filename: 'data.xlsx')
      expect(excel_file.file_extension).to eq('.xlsx')
    end

    it 'returns extension in lowercase' do
      excel_file = build(:excel_file, filename: 'data.XLSX')
      expect(excel_file.file_extension).to eq('.xlsx')
    end
  end

  describe '#file_size_in_mb' do
    it 'returns file size in megabytes' do
      excel_file = build(:excel_file, file_size: 5_242_880) # 5 MB
      expect(excel_file.file_size_in_mb).to eq(5.0)
    end
  end

  describe 'callbacks' do
    describe 'after_create' do
      it 'enqueues analysis job' do
        expect {
          create(:excel_file)
        }.to have_enqueued_job(ExcelAnalysis::AnalysisJob)
      end
    end
  end
end
