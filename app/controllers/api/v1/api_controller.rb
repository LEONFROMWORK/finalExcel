# frozen_string_literal: true

require 'ostruct'
require_relative '../../../shared/errors/domain_error'

module Api
  module V1
    class ApiController < ApplicationController
      # FREE TEST PERIOD - Authentication disabled
      # before_action :authenticate_user!

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

      def current_user
        # FREE TEST PERIOD - Return test user
        if Rails.application.config.free_test_period[:enabled]
          @current_user ||= OpenStruct.new(Rails.application.config.free_test_period[:test_user])
        else
          @current_user ||= Authentication::User.find_by(id: session[:user_id])
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
    end
  end
end
