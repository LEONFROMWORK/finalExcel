# frozen_string_literal: true

module Authentication
  module Services
    class LoginService < ::Shared::BaseClasses::ApplicationService
      attr_reader :email, :password

      def initialize(email:, password:)
        @email = email
        @password = password
      end

      def call
        user = find_user
        return failure([ "Invalid email or password" ], code: :invalid_credentials) unless user

        return failure([ "Invalid email or password" ], code: :invalid_credentials) unless valid_password?(user)

        success(user, message: "Login successful")
      end

      private

      def find_user
        User.find_by(email: email&.downcase)
      end

      def valid_password?(user)
        user.valid_password?(password)
      end
    end
  end
end
