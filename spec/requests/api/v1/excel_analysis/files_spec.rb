# spec/requests/api/v1/excel_analysis/files_spec.rb
require 'rails_helper'

RSpec.describe 'API::V1::ExcelAnalysis::Files', type: :request do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:headers) { auth_headers(user) }
  let(:valid_file) do
    fixture_file_upload(
      Rails.root.join('spec/fixtures/files/sample.xlsx'),
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    )
  end

  describe 'GET /api/v1/excel_analysis/files' do
    let!(:user_files) { create_list(:excel_file, 3, user: user) }
    let!(:other_files) { create_list(:excel_file, 2, user: create(:user)) }

    context 'when authenticated' do
      it 'returns user files' do
        get '/api/v1/excel_analysis/files', headers: headers

        expect(response).to have_http_status(:ok)
        expect(json_response[:files].size).to eq(3)
        expect(json_response[:files].map { |f| f[:id] }).to match_array(user_files.map(&:id))
      end

      it 'paginates results' do
        get '/api/v1/excel_analysis/files', params: { page: 1, per_page: 2 }, headers: headers

        expect(response).to have_http_status(:ok)
        expect(json_response[:files].size).to eq(2)
        expect(json_response[:meta][:total]).to eq(3)
        expect(json_response[:meta][:current_page]).to eq(1)
      end

      it 'filters by status' do
        completed_file = create(:excel_file, :completed, user: user)

        get '/api/v1/excel_analysis/files', params: { status: 'completed' }, headers: headers

        expect(response).to have_http_status(:ok)
        expect(json_response[:files].size).to eq(1)
        expect(json_response[:files].first[:id]).to eq(completed_file.id)
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        get '/api/v1/excel_analysis/files'

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/excel_analysis/files/:id' do
    let(:excel_file) { create(:excel_file, :with_analysis_result, user: user) }

    context 'when authenticated and authorized' do
      it 'returns file details with analysis' do
        get "/api/v1/excel_analysis/files/#{excel_file.id}", headers: headers

        expect(response).to have_http_status(:ok)
        expect(json_response[:file][:id]).to eq(excel_file.id)
        expect(json_response[:file][:analysis_result]).to be_present
      end
    end

    context 'when accessing another user\'s file' do
      let(:other_file) { create(:excel_file, user: create(:user)) }

      it 'returns forbidden' do
        get "/api/v1/excel_analysis/files/#{other_file.id}", headers: headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when admin' do
      let(:headers) { auth_headers(admin) }
      let(:any_file) { create(:excel_file) }

      it 'can access any file' do
        get "/api/v1/excel_analysis/files/#{any_file.id}", headers: headers

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'POST /api/v1/excel_analysis/files' do
    context 'with valid file' do
      it 'uploads file and returns created status' do
        expect {
          post '/api/v1/excel_analysis/files',
               params: { file: valid_file },
               headers: headers
        }.to change(ExcelAnalysis::ExcelFile, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json_response[:file][:filename]).to eq('sample.xlsx')
        expect(json_response[:message]).to include('queued')
      end

      it 'enqueues analysis job' do
        expect {
          post '/api/v1/excel_analysis/files',
               params: { file: valid_file },
               headers: headers
        }.to have_enqueued_job(ExcelAnalysis::AnalysisJob)
      end
    end

    context 'with invalid file' do
      let(:invalid_file) do
        fixture_file_upload(
          Rails.root.join('spec/fixtures/files/invalid.txt'),
          'text/plain'
        )
      end

      it 'returns unprocessable entity' do
        post '/api/v1/excel_analysis/files',
             params: { file: invalid_file },
             headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:errors]).to include(:file_type)
      end
    end

    context 'without file' do
      it 'returns bad request' do
        post '/api/v1/excel_analysis/files',
             params: {},
             headers: headers

        expect(response).to have_http_status(:bad_request)
        expect(json_response[:error]).to include('File is required')
      end
    end
  end

  describe 'DELETE /api/v1/excel_analysis/files/:id' do
    let!(:excel_file) { create(:excel_file, user: user) }

    context 'when owner' do
      it 'deletes the file' do
        expect {
          delete "/api/v1/excel_analysis/files/#{excel_file.id}", headers: headers
        }.to change(ExcelAnalysis::ExcelFile, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end
    end

    context 'when not owner' do
      let(:other_file) { create(:excel_file) }

      it 'returns forbidden' do
        delete "/api/v1/excel_analysis/files/#{other_file.id}", headers: headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'POST /api/v1/excel_analysis/files/:id/reanalyze' do
    let(:excel_file) { create(:excel_file, :completed, user: user) }

    it 'triggers reanalysis' do
      expect {
        post "/api/v1/excel_analysis/files/#{excel_file.id}/reanalyze", headers: headers
      }.to have_enqueued_job(ExcelAnalysis::AnalysisJob).with(excel_file.id)

      expect(response).to have_http_status(:accepted)
      expect(json_response[:message]).to include('Reanalysis started')

      excel_file.reload
      expect(excel_file.status).to eq('processing')
    end
  end

  describe 'GET /api/v1/excel_analysis/files/:id/download' do
    let(:excel_file) { create(:excel_file, user: user) }

    before do
      allow_any_instance_of(ExcelAnalysis::FileStorageService)
        .to receive(:generate_download_url)
        .and_return('https://storage.example.com/download-url')
    end

    it 'returns download URL' do
      get "/api/v1/excel_analysis/files/#{excel_file.id}/download", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response[:download_url]).to eq('https://storage.example.com/download-url')
      expect(json_response[:expires_in]).to be_present
    end
  end
end
