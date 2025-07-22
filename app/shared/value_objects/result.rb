# frozen_string_literal: true

module Shared
  module ValueObjects
    # Result object for service returns
    class Result
      attr_reader :data, :errors, :message, :code

      def initialize(success:, data: nil, errors: [], message: nil, code: nil)
        @success = success
        @data = data
        @errors = Array(errors)
        @message = message
        @code = code
      end

      def success?
        @success
      end

      def failure?
        !@success
      end

      def self.success(data: nil, message: nil)
        new(success: true, data: data, message: message)
      end

      def self.failure(errors: [], message: nil, code: nil)
        new(success: false, errors: errors, message: message, code: code)
      end

      def on_success
        yield(data) if success? && block_given?
        self
      end

      def on_failure
        yield(errors, code) if failure? && block_given?
        self
      end
    end
  end
end

# Alias for easier access
Result = Shared::ValueObjects::Result
