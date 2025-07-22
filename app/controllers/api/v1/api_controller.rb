# frozen_string_literal: true

require "ostruct"
require_relative "../../../shared/errors/domain_error"

module Api
  module V1
    class ApiController < ApplicationController
      # For API endpoints, we'll use JWT token authentication instead of CSRF
      skip_before_action :verify_authenticity_token, if: :jwt_token_present?
      before_action :authenticate_api_user!

      respond_to :json

      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from ActionController::ParameterMissing, with: :bad_request
      rescue_from Shared::Errors::DomainError, with: :handle_domain_error

      private

      def not_found(exception)
        render json: {
          error: "Not found",
          message: exception.message
        }, status: :not_found
      end

      def bad_request(exception)
        render json: {
          error: "Bad request",
          message: exception.message
        }, status: :bad_request
      end

      def handle_domain_error(exception)
        render json: exception.to_h, status: determine_status(exception)
      end

      def determine_status(exception)
        case exception
        when Shared::Errors::NotFoundError
          :not_found
        when Shared::Errors::UnauthorizedError
          :unauthorized
        when Shared::Errors::ValidationError
          :unprocessable_entity
        else
          :internal_server_error
        end
      end

      def jwt_token_present?
        request.headers["Authorization"].present?
      end

      def authenticate_api_user!
        # FREE TEST PERIOD - Always authenticated
        if Rails.application.config.free_test_period[:enabled]
          set_test_user
          return true
        end

        # Check for JWT token in Authorization header
        if jwt_token_present?
          authenticate_with_jwt_token
        else
          # Fall back to standard authentication for web requests
          authenticate_user!
        end
      end

      def authenticate_with_jwt_token
        token = extract_jwt_token
        return render_unauthorized("Missing token") if token.blank?

        payload = JwtService.decode(token)
        return render_unauthorized("Invalid token") if payload.nil?

        # Find and set current user
        @current_user = User.find_by(id: payload[:user_id])
        return render_unauthorized("User not found") if @current_user.nil?

        # Check token expiration (handled by JWT gem, but double-check)
        if payload[:exp] && Time.at(payload[:exp]) < Time.current
          render_unauthorized("Token expired")
        end
      rescue StandardError => e
        Rails.logger.error "JWT authentication failed: #{e.message}"
        render_unauthorized("Authentication failed")
      end

      def extract_jwt_token
        auth_header = request.headers["Authorization"]
        return nil if auth_header.blank?

        # Extract token from "Bearer <token>" format
        auth_header.split(" ").last if auth_header.starts_with?("Bearer ")
      end

      def render_unauthorized(message = "Unauthorized")
        render json: { error: message }, status: :unauthorized
      end

      def set_test_user
        @current_user = OpenStruct.new(Rails.application.config.free_test_period[:test_user])
      end

      def current_user
        @current_user ||= begin
          if Rails.application.config.free_test_period[:enabled]
            OpenStruct.new(Rails.application.config.free_test_period[:test_user])
          else
            User.find_by(id: session[:user_id])
          end
        end
      end

      def authenticate_user!
        # FREE TEST PERIOD - Always authenticated
        return true if Rails.application.config.free_test_period[:enabled]
        render json: { error: "Unauthorized" }, status: :unauthorized unless current_user
      end

      def require_admin!
        # FREE TEST PERIOD - Always admin
        return true if Rails.application.config.free_test_period[:enabled]
        render json: { error: "Forbidden" }, status: :forbidden unless current_user&.admin?
      end

      def authenticate_admin!
        # FREE TEST PERIOD - Always authenticated as admin
        return true if Rails.application.config.free_test_period[:enabled]
        require_admin!
      end

      def render_error(messages, status = :bad_request)
        render json: {
          error: messages.is_a?(Array) ? messages.join(", ") : messages,
          errors: messages.is_a?(Array) ? messages : [ messages ]
        }, status: status
      end
    end
  end
end
