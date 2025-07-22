# frozen_string_literal: true

require "jwt"

class JwtService
  ALGORITHM = "HS256"
  EXPIRATION_TIME = 24.hours

  class << self
    def encode(payload, exp = EXPIRATION_TIME.from_now)
      payload[:exp] = exp.to_i
      payload[:iat] = Time.current.to_i

      JWT.encode(payload, secret_key, ALGORITHM)
    end

    def decode(token)
      return nil if token.blank?

      decoded = JWT.decode(token, secret_key, true, { algorithm: ALGORITHM })
      HashWithIndifferentAccess.new(decoded[0])
    rescue JWT::DecodeError, JWT::ExpiredSignature, JWT::VerificationError => e
      Rails.logger.error "JWT decode error: #{e.message}"
      nil
    end

    def decode!(token)
      decoded = decode(token)
      raise JWT::DecodeError, "Invalid token" if decoded.nil?
      decoded
    end

    private

    def secret_key
      Rails.application.credentials.secret_key_base || Rails.application.secrets.secret_key_base
    end
  end
end
