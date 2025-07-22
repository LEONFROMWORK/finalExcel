# frozen_string_literal: true

module Shared
  module BaseClasses
    # Base service class implementing Result pattern
    class ApplicationService
      include ActiveModel::Model

      def self.call(...)
        new(...).call
      end

      def call
        raise NotImplementedError, "#{self.class} must implement #call"
      end

      protected

      def success(data = nil, message: nil)
        Result.success(data: data, message: message)
      end

      def failure(errors = [], message: nil, code: nil)
        Result.failure(errors: errors, message: message, code: code)
      end
    end
  end
end
