# frozen_string_literal: true

module Authentication
  module Services
    class OauthService < ::Shared::BaseClasses::ApplicationService
      attr_reader :auth_hash

      def initialize(auth_hash)
        @auth_hash = auth_hash
      end

      def call
        user = find_or_create_user
        return failure([ "OAuth authentication failed" ], code: :oauth_error) unless user

        update_user_info(user)
        success(user, message: "OAuth login successful")
      rescue StandardError => e
        Rails.logger.error "OAuth error: #{e.message}"
        failure([ "Authentication failed: #{e.message}" ], code: :oauth_error)
      end

      private

      def find_or_create_user
        User.find_by(email: email) || create_user
      end

      def create_user
        User.create!(
          email: email,
          provider: provider,
          uid: uid,
          name: name,
          password: Devise.friendly_token[0, 20]
        )
      end

      def update_user_info(user)
        user.update!(
          provider: provider,
          uid: uid,
          name: name
        ) if user.provider != provider || user.uid != uid
      end

      def email
        auth_hash.info.email
      end

      def name
        auth_hash.info.name
      end

      def provider
        auth_hash.provider
      end

      def uid
        auth_hash.uid
      end
    end
  end
end
