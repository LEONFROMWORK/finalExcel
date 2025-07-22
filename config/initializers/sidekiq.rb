# frozen_string_literal: true

require 'sidekiq'
require 'sidekiq-cron'

# Sidekiq 서버 설정
Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1') }
  
  # Cron 작업 로드
  schedule_file = Rails.root.join('config', 'schedule.yml')
  
  if File.exist?(schedule_file) && Sidekiq.server?
    Sidekiq::Cron::Job.load_from_hash YAML.load_file(schedule_file)
  end
end

# Sidekiq 클라이언트 설정
Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1') }
end