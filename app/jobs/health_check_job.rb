# frozen_string_literal: true

class HealthCheckJob < ApplicationJob
  queue_as :default
  
  def perform
    monitoring = MonitoringService.instance
    health_status = monitoring.periodic_health_check
    
    # Log the health status
    Rails.logger.info "Health Check: #{health_status['status']} at #{Time.current}"
    
    # Store health metrics if needed
    store_health_metrics(health_status) if defined?(Redis)
    
    # Schedule next check
    self.class.set(wait: 1.minute).perform_later
  rescue StandardError => e
    Rails.logger.error "Health check job failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    # Retry in 5 minutes if failed
    self.class.set(wait: 5.minutes).perform_later
  end
  
  private
  
  def store_health_metrics(health_status)
    redis = Redis.new(url: ENV['REDIS_URL'] || 'redis://localhost:6379')
    
    # Store current status
    redis.setex("health:current", 300, health_status.to_json)
    
    # Store historical data
    timestamp = Time.current.to_i
    redis.zadd("health:history", timestamp, {
      timestamp: timestamp,
      status: health_status['status'],
      services: health_status['services'].transform_values { |v| v[:status] }
    }.to_json)
    
    # Keep only last 24 hours of history
    redis.zremrangebyscore("health:history", 0, timestamp - 86400)
  rescue StandardError => e
    Rails.logger.error "Failed to store health metrics: #{e.message}"
  end
end