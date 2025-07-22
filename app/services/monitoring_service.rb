# frozen_string_literal: true

class MonitoringService
  include Singleton
  
  ALERT_THRESHOLDS = {
    database_latency_ms: 100,
    redis_latency_ms: 50,
    python_service_latency_ms: 500,
    error_rate_percent: 5
  }.freeze
  
  def initialize
    @metrics = {
      requests: 0,
      errors: 0,
      latencies: []
    }
  end
  
  def record_request(success:, latency_ms:)
    @metrics[:requests] += 1
    @metrics[:errors] += 1 unless success
    @metrics[:latencies] << latency_ms
    
    # Keep only last 1000 latencies
    @metrics[:latencies] = @metrics[:latencies].last(1000)
  end
  
  def health_summary
    {
      total_requests: @metrics[:requests],
      total_errors: @metrics[:errors],
      error_rate: error_rate,
      average_latency_ms: average_latency,
      p95_latency_ms: percentile_latency(95),
      p99_latency_ms: percentile_latency(99),
      alerts: check_alerts
    }
  end
  
  def check_system_health
    controller = Api::V1::HealthController.new
    controller.request = ActionDispatch::Request.new({})
    controller.response = ActionDispatch::Response.new
    
    # Call the health check action directly
    controller.index
    
    # Parse the response
    JSON.parse(controller.response.body)
  rescue StandardError => e
    {
      status: 'error',
      error: e.message
    }
  end
  
  def periodic_health_check
    health = check_system_health
    
    # Log critical issues
    if health['status'] != 'healthy'
      Rails.logger.error "System health check failed: #{health.inspect}"
      
      # Send alerts if configured
      send_alerts(health) if should_alert?
    end
    
    health
  end
  
  private
  
  def error_rate
    return 0.0 if @metrics[:requests].zero?
    (@metrics[:errors].to_f / @metrics[:requests] * 100).round(2)
  end
  
  def average_latency
    return 0.0 if @metrics[:latencies].empty?
    (@metrics[:latencies].sum.to_f / @metrics[:latencies].size).round(2)
  end
  
  def percentile_latency(percentile)
    return 0.0 if @metrics[:latencies].empty?
    
    sorted = @metrics[:latencies].sort
    index = (percentile / 100.0 * sorted.size).ceil - 1
    sorted[index] || sorted.last
  end
  
  def check_alerts
    alerts = []
    
    # Check error rate
    if error_rate > ALERT_THRESHOLDS[:error_rate_percent]
      alerts << {
        type: 'high_error_rate',
        message: "Error rate #{error_rate}% exceeds threshold #{ALERT_THRESHOLDS[:error_rate_percent]}%"
      }
    end
    
    # Check latencies
    health = check_system_health
    if health['services']
      health['services'].each do |service, info|
        next unless info.is_a?(Hash) && info['latency_ms']
        
        threshold_key = "#{service}_latency_ms".to_sym
        threshold = ALERT_THRESHOLDS[threshold_key]
        
        if threshold && info['latency_ms'] > threshold
          alerts << {
            type: 'high_latency',
            service: service,
            message: "#{service} latency #{info['latency_ms']}ms exceeds threshold #{threshold}ms"
          }
        end
      end
    end
    
    alerts
  end
  
  def should_alert?
    # Implement alert throttling logic
    true # For now, always alert
  end
  
  def send_alerts(health_data)
    # Implement alert sending (email, Slack, etc.)
    Rails.logger.warn "ALERT: System health degraded - #{health_data.inspect}"
  end
end