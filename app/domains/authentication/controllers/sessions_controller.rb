# frozen_string_literal: true

module Authentication
  class SessionsController < Devise::SessionsController
    skip_before_action :verify_authenticity_token, only: [ :create ]
    respond_to :json

    def create
      result = Services::LoginService.call(
        email: params[:user][:email],
        password: params[:user][:password]
      )

      result.on_success do |user|
        sign_in(user)
        render json: {
          user: user_data(user),
          token: generate_jwt_token(user)
        }, status: :ok
      end.on_failure do |errors, code|
        render json: {
          errors: errors,
          code: code
        }, status: :unauthorized
      end
    end

    def destroy
      sign_out(current_user)
      render json: { message: "Logged out successfully" }, status: :ok
    end

    private

    def user_data(user)
      {
        id: user.id,
        email: user.email,
        name: user.display_name,
        role: user.role
      }
    end

    def generate_jwt_token(user)
      # JWT token generation logic
      # This is a placeholder - implement proper JWT
      SecureRandom.hex(32)
    end
  end
end
