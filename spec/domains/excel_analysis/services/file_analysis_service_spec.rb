# spec/domains/excel_analysis/services/file_analysis_service_spec.rb
require 'rails_helper'

RSpec.describe ExcelAnalysis::FileAnalysisService do
  let(:user) { create(:user) }
  let(:valid_file) do
    fixture_file_upload(
      Rails.root.join('spec/fixtures/files/sample.xlsx'),
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    )
  end
  let(:invalid_file) do
    fixture_file_upload(
      Rails.root.join('spec/fixtures/files/invalid.txt'),
      'text/plain'
    )
  end
  let(:oversized_file) do
    double(
      original_filename: 'huge.xlsx',
      content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      size: 51.megabytes
    )
  end

  describe '#call' do
    context 'with valid Excel file' do
      it 'creates an excel file record' do
        expect {
          described_class.call(file: valid_file, user: user)
        }.to change(ExcelAnalysis::ExcelFile, :count).by(1)
      end

      it 'returns success result with file data' do
        result = described_class.call(file: valid_file, user: user)

        expect(result).to be_success
        expect(result.data[:file]).to be_a(ExcelAnalysis::ExcelFile)
        expect(result.data[:file].filename).to eq('sample.xlsx')
        expect(result.data[:file].user).to eq(user)
      end

      it 'enqueues analysis job' do
        expect {
          described_class.call(file: valid_file, user: user)
        }.to have_enqueued_job(ExcelAnalysis::AnalysisJob)
      end

      it 'uploads file to storage' do
        expect_any_instance_of(ExcelAnalysis::FileStorageService).to receive(:upload).and_return('https://storage.example.com/file.xlsx')

        result = described_class.call(file: valid_file, user: user)
        expect(result.data[:file].file_url).to eq('https://storage.example.com/file.xlsx')
      end
    end

    context 'with invalid file type' do
      it 'does not create excel file record' do
        expect {
          described_class.call(file: invalid_file, user: user)
        }.not_to change(ExcelAnalysis::ExcelFile, :count)
      end

      it 'returns failure result' do
        result = described_class.call(file: invalid_file, user: user)

        expect(result).to be_failure
        expect(result.code).to eq(:invalid_file)
        expect(result.errors).to include(:file_type)
      end
    end

    context 'with oversized file' do
      it 'returns failure result' do
        result = described_class.call(file: oversized_file, user: user)

        expect(result).to be_failure
        expect(result.code).to eq(:invalid_file)
        expect(result.errors).to include(:file_size)
      end
    end

    context 'when storage upload fails' do
      before do
        allow_any_instance_of(ExcelAnalysis::FileStorageService).to receive(:upload).and_raise(StandardError, 'Storage error')
      end

      it 'returns failure result' do
        result = described_class.call(file: valid_file, user: user)

        expect(result).to be_failure
        expect(result.code).to eq(:storage_error)
        expect(result.message).to include('Storage error')
      end

      it 'does not create excel file record' do
        expect {
          described_class.call(file: valid_file, user: user)
        }.not_to change(ExcelAnalysis::ExcelFile, :count)
      end
    end

    context 'with metadata extraction' do
      it 'extracts and stores file metadata' do
        result = described_class.call(file: valid_file, user: user)
        excel_file = result.data[:file]

        expect(excel_file.metadata).to be_present
        expect(excel_file.metadata).to include(
          'mime_type' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          'uploaded_at' => be_a(String)
        )
      end
    end
  end

  describe 'validation' do
    it 'validates file presence' do
      result = described_class.call(file: nil, user: user)

      expect(result).to be_failure
      expect(result.errors).to include(:file)
    end

    it 'validates user presence' do
      result = described_class.call(file: valid_file, user: nil)

      expect(result).to be_failure
      expect(result.errors).to include(:user)
    end

    it 'validates file extension' do
      csv_file = double(
        original_filename: 'data.csv',
        content_type: 'text/csv',
        size: 1.megabyte
      )

      result = described_class.call(file: csv_file, user: user)

      expect(result).to be_failure
      expect(result.errors[:file_type]).to include('must be an Excel file')
    end
  end
end
