# frozen_string_literal: true

module Authentication
  class RegistrationsController < Devise::RegistrationsController
    skip_before_action :verify_authenticity_token, only: [ :create ]
    respond_to :json

    def create
      result = Services::RegistrationService.call(sign_up_params)

      result.on_success do |user|
        sign_in(user)
        render json: {
          user: user_data(user),
          token: generate_jwt_token(user)
        }, status: :created
      end.on_failure do |errors, code|
        render json: {
          errors: errors,
          code: code
        }, status: :unprocessable_entity
      end
    end

    private

    def sign_up_params
      params.require(:user).permit(:email, :password, :password_confirmation, :name)
    end

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
      SecureRandom.hex(32)
    end
  end
end
