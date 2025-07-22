# frozen_string_literal: true

module Authentication
  module Services
    class RegistrationService < ::Shared::BaseClasses::ApplicationService
      attr_reader :params

      def initialize(params)
        @params = params
      end

      def call
        user = User.new(user_params)

        if user.save
          success(user, message: "Registration successful")
        else
          failure(user.errors.full_messages, code: :validation_error)
        end
      end

      private

      def user_params
        params.slice(:email, :password, :password_confirmation, :name)
      end
    end
  end
end
