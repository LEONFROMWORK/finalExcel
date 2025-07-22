# frozen_string_literal: true

class ApiUsageTracker < ApplicationRecord
  # API 서비스 타입
  API_SERVICES = {
    openai_embedding: 'openai_embedding',
    openai_chat: 'openai_chat',
    openrouter_chat: 'openrouter_chat',
    openrouter_image: 'openrouter_image'
  }.freeze
  
  # 토큰 비용 (USD per 1M tokens)
  PRICING = {
    'text-embedding-3-small' => { input: 0.02 },
    'text-embedding-3-large' => { input: 0.13 },
    'gpt-4-turbo' => { input: 10.0, output: 30.0 },
    'gpt-3.5-turbo' => { input: 0.5, output: 1.5 }
  }.freeze
  
  # 유효성 검사
  validates :service, presence: true, inclusion: { in: API_SERVICES.values }
  validates :model, presence: true
  validates :tokens_used, numericality: { greater_than_or_equal_to: 0 }
  validates :cost, numericality: { greater_than_or_equal_to: 0 }
  
  # 스코프
  scope :by_service, ->(service) { where(service: service) }
  scope :by_model, ->(model) { where(model: model) }
  scope :today, -> { where(created_at: Time.current.beginning_of_day..Time.current.end_of_day) }
  scope :this_month, -> { where(created_at: Time.current.beginning_of_month..Time.current.end_of_month) }
  scope :recent, -> { order(created_at: :desc) }
  
  # 클래스 메서드
  class << self
    # API 사용 기록
    def track_usage(service:, model:, tokens:, request_type: 'input', metadata: {})
      pricing = PRICING[model]
      return unless pricing
      
      cost = calculate_cost(tokens, pricing[request_type.to_sym] || pricing[:input])
      
      create!(
        service: service,
        model: model,
        tokens_used: tokens,
        cost: cost,
        request_type: request_type,
        metadata: metadata
      )
    end
    
    # 임베딩 사용 추적
    def track_embedding(text, model = 'text-embedding-3-small')
      # 대략적인 토큰 계산 (영어: ~4 chars/token, 한국어: ~2 chars/token)
      estimated_tokens = (text.length / 3.0).ceil
      
      track_usage(
        service: API_SERVICES[:openai_embedding],
        model: model,
        tokens: estimated_tokens,
        metadata: {
          text_length: text.length,
          text_preview: text[0..100]
        }
      )
    end
    
    # 사용량 통계
    def usage_stats(period = :this_month)
      scope = case period
              when :today then today
              when :this_month then this_month
              when :last_month
                last_month = 1.month.ago
                where(created_at: last_month.beginning_of_month..last_month.end_of_month)
              else
                all
              end
      
      {
        total_requests: scope.count,
        total_tokens: scope.sum(:tokens_used),
        total_cost: scope.sum(:cost).round(2),
        by_service: scope.group(:service).sum(:cost).transform_values { |v| v.round(2) },
        by_model: scope.group(:model).sum(:cost).transform_values { |v| v.round(2) },
        daily_usage: daily_usage(scope),
        cost_projection: project_monthly_cost(scope)
      }
    end
    
    # 일별 사용량
    def daily_usage(scope)
      scope.group("DATE(created_at)").sum(:cost).transform_keys { |k| k.to_s }.transform_values { |v| v.round(2) }
    end
    
    # 월간 비용 예측
    def project_monthly_cost(scope)
      return 0 if scope.empty?
      
      days_in_period = (scope.maximum(:created_at).to_date - scope.minimum(:created_at).to_date).to_i + 1
      return 0 if days_in_period == 0
      
      daily_average = scope.sum(:cost) / days_in_period
      monthly_projection = daily_average * 30
      
      {
        daily_average: daily_average.round(2),
        monthly_projection: monthly_projection.round(2),
        based_on_days: days_in_period
      }
    end
    
    # 사용량 알림
    def check_usage_limits
      monthly_cost = this_month.sum(:cost)
      
      warnings = []
      
      # 월간 한도 체크
      if monthly_cost > 50.0
        warnings << { level: :critical, message: "Monthly cost exceeded $50: $#{monthly_cost.round(2)}" }
      elsif monthly_cost > 30.0
        warnings << { level: :warning, message: "Monthly cost approaching limit: $#{monthly_cost.round(2)}" }
      end
      
      # 일일 한도 체크
      daily_cost = today.sum(:cost)
      if daily_cost > 5.0
        warnings << { level: :warning, message: "Daily cost high: $#{daily_cost.round(2)}" }
      end
      
      warnings
    end
    
    private
    
    def calculate_cost(tokens, price_per_million)
      (tokens.to_f / 1_000_000) * price_per_million
    end
  end
  
  # 인스턴스 메서드
  def cost_in_cents
    (cost * 100).round
  end
  
  def hourly_rate
    return 0 if created_at.nil?
    
    hours_ago = (Time.current - created_at) / 3600.0
    return 0 if hours_ago == 0
    
    (cost / hours_ago).round(4)
  end
end