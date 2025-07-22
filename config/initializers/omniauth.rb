# OmniAuth configuration
Rails.application.config.middleware.use OmniAuth::Builder do
  # Configure allowed request methods
  OmniAuth.config.allowed_request_methods = [ :post, :get ]

  # Configure full host for callbacks
  OmniAuth.config.full_host = Rails.env.production? ? ENV["APP_URL"] : "http://localhost:3000"

  # Silence OmniAuth logs in production
  OmniAuth.config.logger = Rails.logger
  OmniAuth.config.logger.level = Logger::INFO if Rails.env.production?
end
