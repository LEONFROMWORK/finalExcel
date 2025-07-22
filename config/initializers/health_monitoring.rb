# frozen_string_literal: true

# Start health monitoring if enabled
if ENV["ENABLE_HEALTH_MONITORING"] == "true" && Rails.env.production?
  Rails.application.config.after_initialize do
    # Start periodic health checks after a delay
    HealthCheckJob.set(wait: 30.seconds).perform_later

    Rails.logger.info "Health monitoring enabled - checks will run every minute"
  end
end
