# spec/security/authentication_spec.rb
require 'rails_helper'

RSpec.describe 'Authentication Security', type: :request do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }

  describe 'JWT Token Security' do
    context 'token validation' do
      it 'rejects expired tokens' do
        expired_token = JWT.encode(
          { user_id: user.id, exp: 1.hour.ago.to_i },
          Rails.application.credentials.secret_key_base
        )

        get '/api/v1/profile', headers: { 'Authorization' => "Bearer #{expired_token}" }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response[:error]).to include('expired')
      end

      it 'rejects tokens with invalid signature' do
        invalid_token = JWT.encode(
          { user_id: user.id, exp: 1.hour.from_now.to_i },
          'wrong_secret'
        )

        get '/api/v1/profile', headers: { 'Authorization' => "Bearer #{invalid_token}" }

        expect(response).to have_http_status(:unauthorized)
      end

      it 'rejects malformed tokens' do
        get '/api/v1/profile', headers: { 'Authorization' => "Bearer malformed.token.here" }

        expect(response).to have_http_status(:unauthorized)
      end

      it 'rejects tokens for non-existent users' do
        token = JWT.encode(
          { user_id: 999999, exp: 1.hour.from_now.to_i },
          Rails.application.credentials.secret_key_base
        )

        get '/api/v1/profile', headers: { 'Authorization' => "Bearer #{token}" }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'token expiration' do
      it 'accepts tokens within expiration time' do
        token = JWT.encode(
          { user_id: user.id, exp: 1.hour.from_now.to_i },
          Rails.application.credentials.secret_key_base
        )

        get '/api/v1/profile', headers: { 'Authorization' => "Bearer #{token}" }

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'Role-based Access Control' do
    context 'admin endpoints' do
      it 'prevents regular users from accessing admin endpoints' do
        get '/api/v1/admin/users', headers: auth_headers(user)

        expect(response).to have_http_status(:forbidden)
        expect(json_response[:error]).to include('admin')
      end

      it 'allows admins to access admin endpoints' do
        get '/api/v1/admin/users', headers: auth_headers(admin)

        expect(response).to have_http_status(:ok)
      end
    end

    context 'resource ownership' do
      let(:user_file) { create(:excel_file, user: user) }
      let(:other_file) { create(:excel_file, user: create(:user)) }

      it 'prevents users from accessing other users resources' do
        get "/api/v1/excel_analysis/files/#{other_file.id}", headers: auth_headers(user)

        expect(response).to have_http_status(:forbidden)
      end

      it 'allows users to access their own resources' do
        get "/api/v1/excel_analysis/files/#{user_file.id}", headers: auth_headers(user)

        expect(response).to have_http_status(:ok)
      end

      it 'allows admins to access any resource' do
        get "/api/v1/excel_analysis/files/#{other_file.id}", headers: auth_headers(admin)

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'Rate Limiting' do
    it 'limits login attempts' do
      invalid_params = { email: user.email, password: 'wrong' }.to_json
      headers = { 'Content-Type' => 'application/json' }

      # Make multiple failed login attempts
      10.times do
        post '/api/v1/auth/login', params: invalid_params, headers: headers
      end

      # The next attempt should be rate limited
      post '/api/v1/auth/login', params: invalid_params, headers: headers

      expect(response).to have_http_status(:too_many_requests)
      expect(json_response[:error]).to include('Too many requests')
    end
  end

  describe 'Session Security' do
    it 'invalidates tokens after logout' do
      headers = auth_headers(user)

      # First, verify the token works
      get '/api/v1/profile', headers: headers
      expect(response).to have_http_status(:ok)

      # Logout
      delete '/api/v1/auth/logout', headers: headers
      expect(response).to have_http_status(:ok)

      # Try to use the same token
      get '/api/v1/profile', headers: headers
      expect(response).to have_http_status(:unauthorized)
    end

    it 'prevents session fixation attacks' do
      # Login and get a token
      post '/api/v1/auth/login',
           params: { email: user.email, password: 'password123' }.to_json,
           headers: { 'Content-Type' => 'application/json' }

      first_token = json_response[:token]

      # Login again
      post '/api/v1/auth/login',
           params: { email: user.email, password: 'password123' }.to_json,
           headers: { 'Content-Type' => 'application/json' }

      second_token = json_response[:token]

      # Tokens should be different
      expect(first_token).not_to eq(second_token)
    end
  end

  describe 'Password Security' do
    it 'enforces minimum password length' do
      post '/api/v1/auth/register',
           params: {
             email: 'short@example.com',
             password: '12345',
             password_confirmation: '12345'
           }.to_json,
           headers: { 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response[:errors][:password]).to include('is too short')
    end

    it 'requires current password for profile updates' do
      patch '/api/v1/profile',
            params: { name: 'New Name' }.to_json,
            headers: auth_headers(user)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response[:errors][:current_password]).to include("can't be blank")
    end

    it 'does not expose password in responses' do
      get '/api/v1/profile', headers: auth_headers(user)

      expect(json_response[:user]).not_to have_key(:password)
      expect(json_response[:user]).not_to have_key(:encrypted_password)
      expect(json_response[:user]).not_to have_key(:password_digest)
    end
  end

  describe 'CORS Security' do
    it 'includes proper CORS headers for allowed origins' do
      get '/api/v1/profile',
          headers: auth_headers(user).merge('Origin' => 'http://localhost:3000')

      expect(response.headers['Access-Control-Allow-Origin']).to eq('http://localhost:3000')
      expect(response.headers['Access-Control-Allow-Credentials']).to eq('true')
    end

    it 'rejects requests from unauthorized origins' do
      get '/api/v1/profile',
          headers: auth_headers(user).merge('Origin' => 'http://malicious-site.com')

      expect(response.headers['Access-Control-Allow-Origin']).to be_nil
    end
  end

  describe 'SQL Injection Protection' do
    it 'sanitizes user input in queries' do
      # Attempt SQL injection in search parameter
      get '/api/v1/knowledge_base/qa_pairs',
          params: { q: "'; DROP TABLE users; --" },
          headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      expect(Authentication::User.count).to be > 0 # Table should still exist
    end
  end

  describe 'XSS Protection' do
    it 'sanitizes user-generated content' do
      malicious_content = '<script>alert("XSS")</script>'

      post '/api/v1/knowledge_base/qa_pairs',
           params: {
             question: malicious_content,
             answer: 'Safe answer'
           }.to_json,
           headers: auth_headers(user)

      expect(response).to have_http_status(:created)

      # Verify the content is sanitized when retrieved
      get "/api/v1/knowledge_base/qa_pairs/#{json_response[:qa_pair][:id]}",
          headers: auth_headers(user)

      expect(json_response[:qa_pair][:question]).not_to include('<script>')
      expect(json_response[:qa_pair][:question]).not_to include('alert')
    end
  end
end
