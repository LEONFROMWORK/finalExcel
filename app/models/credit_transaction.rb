# frozen_string_literal: true

# 크레딧 거래 내역 모델
class CreditTransaction < ApplicationRecord
  belongs_to :user
  belongs_to :related_transaction, class_name: 'CreditTransaction', optional: true
  
  # 거래 타입
  TRANSACTION_TYPES = {
    signup_bonus: 'signup_bonus',           # 가입 보너스
    referral_bonus: 'referral_bonus',       # 추천 보너스
    purchase: 'purchase',                   # 크레딧 구매
    subscription_credit: 'subscription_credit', # 구독 크레딧
    usage: 'usage',                         # 사용
    refund: 'refund',                       # 환불
    adjustment: 'adjustment',               # 조정
    reward: 'reward'                        # 보상
  }.freeze
  
  # 상태
  STATUSES = {
    pending: 'pending',
    completed: 'completed',
    failed: 'failed',
    refunded: 'refunded'
  }.freeze
  
  # 검증
  validates :transaction_type, presence: true, inclusion: { in: TRANSACTION_TYPES.values }
  validates :status, presence: true, inclusion: { in: STATUSES.values }
  validates :amount, presence: true, numericality: true
  validates :balance_after, presence: true, numericality: { greater_than_or_equal_to: 0 }
  
  # 스코프
  scope :completed, -> { where(status: 'completed') }
  scope :pending, -> { where(status: 'pending') }
  scope :credits_in, -> { where('amount > 0') }
  scope :credits_out, -> { where('amount < 0') }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_type, ->(type) { where(transaction_type: type) }
  
  # 콜백
  before_validation :set_defaults
  after_create :send_notification
  
  # 클래스 메서드
  class << self
    def daily_summary(user, date = Date.current)
      transactions = user.credit_transactions
                        .where(created_at: date.beginning_of_day..date.end_of_day)
                        .completed
      
      {
        date: date,
        credits_earned: transactions.credits_in.sum(:amount),
        credits_spent: transactions.credits_out.sum(:amount).abs,
        transaction_count: transactions.count,
        ending_balance: transactions.last&.balance_after || user.credits
      }
    end
    
    def monthly_summary(user, month = Date.current)
      start_date = month.beginning_of_month
      end_date = month.end_of_month
      
      transactions = user.credit_transactions
                        .where(created_at: start_date..end_date)
                        .completed
      
      {
        month: month.strftime('%Y-%m'),
        credits_earned: transactions.credits_in.sum(:amount),
        credits_spent: transactions.credits_out.sum(:amount).abs,
        purchases: transactions.by_type('purchase').sum(:price_paid),
        transaction_count: transactions.count,
        daily_breakdown: daily_breakdown(transactions)
      }
    end
    
    private
    
    def daily_breakdown(transactions)
      transactions.group_by { |t| t.created_at.to_date }
                 .transform_values do |daily_transactions|
        {
          credits_in: daily_transactions.select { |t| t.amount > 0 }.sum(&:amount),
          credits_out: daily_transactions.select { |t| t.amount < 0 }.sum(&:amount).abs,
          count: daily_transactions.count
        }
      end
    end
  end
  
  # 인스턴스 메서드
  
  def credit_in?
    amount > 0
  end
  
  def credit_out?
    amount < 0
  end
  
  def refundable?
    transaction_type == 'purchase' && 
      status == 'completed' && 
      created_at > 7.days.ago &&
      !refunded?
  end
  
  def refunded?
    status == 'refunded' || 
      CreditTransaction.exists?(
        related_transaction_id: id,
        transaction_type: 'refund',
        status: 'completed'
      )
  end
  
  def description
    case transaction_type
    when 'signup_bonus'
      '회원가입 보너스'
    when 'referral_bonus'
      '추천인 보너스'
    when 'purchase'
      "크레딧 구매 (#{amount}개)"
    when 'subscription_credit'
      '구독 크레딧'
    when 'usage'
      usage_description
    when 'refund'
      '환불'
    when 'adjustment'
      metadata['reason'] || '크레딧 조정'
    when 'reward'
      metadata['reason'] || '보상'
    else
      transaction_type.humanize
    end
  end
  
  private
  
  def set_defaults
    self.status ||= 'completed'
    self.metadata ||= {}
  end
  
  def send_notification
    # 알림 시스템이 구현되면 여기서 알림 전송
    return unless credit_in? && amount >= 100
    
    # 대량 크레딧 획득 시 알림
    # NotificationService.new(user).send_credit_notification(self)
  end
  
  def usage_description
    service = metadata['service']
    case service
    when 'ai_chat'
      'AI 상담 사용'
    when 'excel_analysis'
      'Excel 분석'
    when 'vba_advanced'
      'VBA 고급 해결'
    else
      '서비스 사용'
    end
  end
end