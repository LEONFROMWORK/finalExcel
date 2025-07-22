# spec/requests/api/v1/authentication/sessions_spec.rb
require 'rails_helper'

RSpec.describe 'API::V1::Authentication::Sessions', type: :request do
  let(:user) { create(:user, password: 'password123') }

  describe 'POST /api/v1/auth/login' do
    context 'with valid credentials' do
      let(:valid_params) do
        {
          email: user.email,
          password: 'password123'
        }
      end

      it 'returns success with user data and token' do
        post '/api/v1/auth/login', params: valid_params.to_json, headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:ok)
        expect(json_response[:user]).to include(
          id: user.id,
          email: user.email,
          role: user.role
        )
        expect(json_response[:token]).to be_present
      end

      it 'returns valid JWT token' do
        post '/api/v1/auth/login', params: valid_params.to_json, headers: { 'Content-Type' => 'application/json' }

        token = json_response[:token]
        decoded_token = JWT.decode(
          token,
          Rails.application.credentials.secret_key_base,
          true,
          algorithm: 'HS256'
        )

        expect(decoded_token.first['user_id']).to eq(user.id)
      end
    end

    context 'with invalid email' do
      let(:invalid_params) do
        {
          email: 'nonexistent@example.com',
          password: 'password123'
        }
      end

      it 'returns unauthorized' do
        post '/api/v1/auth/login', params: invalid_params.to_json, headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response[:error]).to eq('Invalid email or password')
      end
    end

    context 'with invalid password' do
      let(:invalid_params) do
        {
          email: user.email,
          password: 'wrongpassword'
        }
      end

      it 'returns unauthorized' do
        post '/api/v1/auth/login', params: invalid_params.to_json, headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response[:error]).to eq('Invalid email or password')
      end
    end

    context 'with unconfirmed user' do
      let(:unconfirmed_user) { create(:user, :unconfirmed) }
      let(:params) do
        {
          email: unconfirmed_user.email,
          password: 'password123'
        }
      end

      it 'returns unauthorized with specific message' do
        post '/api/v1/auth/login', params: params.to_json, headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response[:error]).to include('confirm your email')
      end
    end
  end

  describe 'DELETE /api/v1/auth/logout' do
    let(:headers) { auth_headers(user) }

    context 'when authenticated' do
      it 'returns success' do
        delete '/api/v1/auth/logout', headers: headers

        expect(response).to have_http_status(:ok)
        expect(json_response[:message]).to eq('Logged out successfully')
      end

      it 'invalidates the token' do
        delete '/api/v1/auth/logout', headers: headers

        # Try to use the same token again
        get '/api/v1/profile', headers: headers

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        delete '/api/v1/auth/logout'

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/auth/register' do
    context 'with valid params' do
      let(:valid_params) do
        {
          email: 'newuser@example.com',
          password: 'password123',
          password_confirmation: 'password123',
          name: 'New User'
        }
      end

      it 'creates a new user' do
        expect {
          post '/api/v1/auth/register', params: valid_params.to_json, headers: { 'Content-Type' => 'application/json' }
        }.to change(Authentication::User, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json_response[:user][:email]).to eq('newuser@example.com')
        expect(json_response[:token]).to be_present
      end

      it 'sends confirmation email' do
        expect {
          post '/api/v1/auth/register', params: valid_params.to_json, headers: { 'Content-Type' => 'application/json' }
        }.to have_enqueued_mail(Devise::Mailer, :confirmation_instructions)
      end
    end

    context 'with existing email' do
      let(:invalid_params) do
        {
          email: user.email,
          password: 'password123',
          password_confirmation: 'password123',
          name: 'Duplicate User'
        }
      end

      it 'returns unprocessable entity' do
        post '/api/v1/auth/register', params: invalid_params.to_json, headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:errors][:email]).to include('has already been taken')
      end
    end

    context 'with password mismatch' do
      let(:invalid_params) do
        {
          email: 'newuser@example.com',
          password: 'password123',
          password_confirmation: 'differentpassword',
          name: 'New User'
        }
      end

      it 'returns unprocessable entity' do
        post '/api/v1/auth/register', params: invalid_params.to_json, headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:errors][:password_confirmation]).to include("doesn't match Password")
      end
    end
  end

  describe 'GET /api/v1/profile' do
    let(:headers) { auth_headers(user) }

    context 'when authenticated' do
      it 'returns current user data' do
        get '/api/v1/profile', headers: headers

        expect(response).to have_http_status(:ok)
        expect(json_response[:user]).to include(
          id: user.id,
          email: user.email,
          name: user.name,
          role: user.role
        )
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        get '/api/v1/profile'

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with expired token' do
      let(:expired_token) do
        JWT.encode(
          { user_id: user.id, exp: 1.hour.ago.to_i },
          Rails.application.credentials.secret_key_base
        )
      end
      let(:headers) { { 'Authorization' => "Bearer #{expired_token}" } }

      it 'returns unauthorized' do
        get '/api/v1/profile', headers: headers

        expect(response).to have_http_status(:unauthorized)
        expect(json_response[:error]).to include('expired')
      end
    end
  end

  describe 'PATCH /api/v1/profile' do
    let(:headers) { auth_headers(user) }

    context 'with valid params' do
      let(:update_params) do
        {
          name: 'Updated Name',
          current_password: 'password123'
        }
      end

      it 'updates user profile' do
        patch '/api/v1/profile', params: update_params.to_json, headers: headers

        expect(response).to have_http_status(:ok)
        expect(json_response[:user][:name]).to eq('Updated Name')

        user.reload
        expect(user.name).to eq('Updated Name')
      end
    end

    context 'when changing password' do
      let(:password_params) do
        {
          current_password: 'password123',
          password: 'newpassword123',
          password_confirmation: 'newpassword123'
        }
      end

      it 'updates password' do
        patch '/api/v1/profile', params: password_params.to_json, headers: headers

        expect(response).to have_http_status(:ok)

        user.reload
        expect(user.valid_password?('newpassword123')).to be true
      end
    end

    context 'with invalid current password' do
      let(:invalid_params) do
        {
          name: 'Updated Name',
          current_password: 'wrongpassword'
        }
      end

      it 'returns unprocessable entity' do
        patch '/api/v1/profile', params: invalid_params.to_json, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:errors][:current_password]).to include('is invalid')
      end
    end
  end
end
