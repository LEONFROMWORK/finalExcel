# frozen_string_literal: true

module Shared
  module Errors
    # Base domain error class
    class DomainError < StandardError
      attr_reader :code, :details

      def initialize(message = nil, code: nil, details: {})
        super(message)
        @code = code
        @details = details
      end

      def to_h
        {
          error: self.class.name.demodulize.underscore,
          message: message,
          code: code,
          details: details
        }
      end
    end

    # Specific domain errors
    class ValidationError < DomainError
      def initialize(message = "Validation failed", details: {})
        super(message, code: "VALIDATION_ERROR", details: details)
      end
    end

    class NotFoundError < DomainError
      def initialize(resource = "Resource", id = nil)
        message = id ? "#{resource} with id #{id} not found" : "#{resource} not found"
        super(message, code: "NOT_FOUND")
      end
    end

    class UnauthorizedError < DomainError
      def initialize(message = "Unauthorized access")
        super(message, code: "UNAUTHORIZED")
      end
    end

    class ServiceUnavailableError < DomainError
      def initialize(service = "Service", message = nil)
        message ||= "#{service} is temporarily unavailable"
        super(message, code: "SERVICE_UNAVAILABLE")
      end
    end
  end
end
