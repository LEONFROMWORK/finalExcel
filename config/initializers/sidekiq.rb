# frozen_string_literal: true

require "sidekiq"
require "sidekiq-cron"

# Skip Sidekiq configuration if Redis is not available
if ENV["REDIS_URL"].present?
  # Sidekiq 서버 설정
  Sidekiq.configure_server do |config|
    config.redis = {
      url: ENV["REDIS_URL"],
      ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE } # For Upstash Redis
    }

    # Cron 작업 로드
    schedule_file = Rails.root.join("config", "schedule.yml")

    if File.exist?(schedule_file) && Sidekiq.server?
      Sidekiq::Cron::Job.load_from_hash YAML.load_file(schedule_file)
    end
  end

  # Sidekiq 클라이언트 설정
  Sidekiq.configure_client do |config|
    config.redis = {
      url: ENV["REDIS_URL"],
      ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE } # For Upstash Redis
    }
  end
else
  Rails.logger.warn "Sidekiq not configured - REDIS_URL not found"
end
