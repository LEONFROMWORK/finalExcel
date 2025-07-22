# frozen_string_literal: true

# 추천 보상 모델
class ReferralReward < ApplicationRecord
  belongs_to :referral_code
  belongs_to :referrer, class_name: 'User', foreign_key: 'referrer_id'
  belongs_to :referred, class_name: 'User', foreign_key: 'referred_id'
  
  # 보상 타입
  REWARD_TYPES = {
    signup: 'signup',         # 회원가입 보상
    purchase: 'purchase',     # 구매 보상
    milestone: 'milestone',   # 마일스톤 보상
    bonus: 'bonus'           # 보너스 보상
  }.freeze
  
  # 상태
  STATUSES = {
    pending: 'pending',       # 대기 중
    approved: 'approved',     # 승인됨
    paid: 'paid',            # 지급됨
    cancelled: 'cancelled',   # 취소됨
    expired: 'expired'       # 만료됨
  }.freeze
  
  # 검증
  validates :reward_type, presence: true, inclusion: { in: REWARD_TYPES.values }
  validates :status, presence: true, inclusion: { in: STATUSES.values }
  validates :credits_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :referrer_id, presence: true
  validates :referred_id, presence: true
  validate :referrer_and_referred_are_different
  
  # 스코프
  scope :pending, -> { where(status: STATUSES[:pending]) }
  scope :approved, -> { where(status: STATUSES[:approved]) }
  scope :paid, -> { where(status: STATUSES[:paid]) }
  scope :cancelled, -> { where(status: STATUSES[:cancelled]) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_referrer, ->(user) { where(referrer_id: user.id) }
  scope :by_referred, ->(user) { where(referred_id: user.id) }
  scope :by_type, ->(type) { where(reward_type: type) }
  
  # 콜백
  after_create :notify_referrer
  after_update :process_status_change, if: :saved_change_to_status?
  
  # 클래스 메서드
  class << self
    # 보상 승인 및 지급 처리
    def process_pending_rewards
      pending.where('created_at <= ?', 7.days.ago).find_each do |reward|
        reward.approve_and_pay!
      end
    end
    
    # 통계
    def statistics(user = nil)
      rewards = user ? by_referrer(user) : all
      
      {
        total_rewards: rewards.count,
        total_earned: rewards.paid.sum(:credits_amount),
        pending_amount: rewards.pending.sum(:credits_amount),
        by_type: rewards.group(:reward_type).count,
        by_status: rewards.group(:status).count,
        monthly_earnings: calculate_monthly_earnings(rewards)
      }
    end
    
    private
    
    def calculate_monthly_earnings(rewards)
      rewards.paid
             .where('rewarded_at >= ?', 12.months.ago)
             .group_by { |r| r.rewarded_at.beginning_of_month }
             .transform_values { |rs| rs.sum(&:credits_amount) }
    end
  end
  
  # 인스턴스 메서드
  
  # 승인
  def approve!
    return false unless pending?
    
    update!(status: STATUSES[:approved])
  end
  
  # 지급
  def pay!
    return false unless approved?
    
    transaction do
      # 크레딧 지급
      referrer.increment!(:credits, credits_amount)
      
      # 크레딧 거래 기록
      CreditTransaction.create!(
        user: referrer,
        transaction_type: 'referral_bonus',
        amount: credits_amount,
        balance_after: referrer.credits,
        status: 'completed',
        metadata: {
          reward_id: id,
          reward_type: reward_type,
          referred_user_id: referred_id
        }
      )
      
      # 상태 업데이트
      update!(
        status: STATUSES[:paid],
        rewarded_at: Time.current
      )
      
      # 활동 기록
      UserActivity.track(
        user: referrer,
        action: 'referral_reward_paid',
        details: {
          reward_id: id,
          amount: credits_amount,
          referred_user: referred.email
        }
      )
      
      # 알림 전송
      NotificationService.new(referrer).send_referral_reward_notification(self)
      
      true
    end
  rescue => e
    Rails.logger.error "Reward payment failed: #{e.message}"
    false
  end
  
  # 승인 후 바로 지급
  def approve_and_pay!
    approve! && pay!
  end
  
  # 승인 가능 여부
  def can_be_approved?
    pending? && referrer.present? && referred.present?
  end
  
  # 취소
  def cancel!(reason = nil)
    return false if paid?
    
    update!(
      status: STATUSES[:cancelled],
      metadata: metadata.merge(cancellation_reason: reason, cancelled_at: Time.current)
    )
  end
  
  # 상태 확인
  def pending?
    status == STATUSES[:pending]
  end
  
  def approved?
    status == STATUSES[:approved]
  end
  
  def paid?
    status == STATUSES[:paid]
  end
  
  def cancelled?
    status == STATUSES[:cancelled]
  end
  
  # 설명 텍스트
  def description
    case reward_type
    when REWARD_TYPES[:signup]
      "#{referred.email} 회원가입 보상"
    when REWARD_TYPES[:purchase]
      amount = metadata['purchase_amount']
      "#{referred.email} 구매 보상 (#{format_currency(amount)})"
    when REWARD_TYPES[:milestone]
      "#{metadata['milestone_name']} 달성 보상"
    when REWARD_TYPES[:bonus]
      metadata['bonus_reason'] || "보너스 보상"
    else
      "추천 보상"
    end
  end
  
  private
  
  def referrer_and_referred_are_different
    if referrer_id == referred_id
      errors.add(:referred_id, "자기 자신을 추천할 수 없습니다")
    end
  end
  
  def notify_referrer
    # 이메일 알림 (향후 구현)
    # ReferralMailer.reward_created(self).deliver_later
    
    # 인앱 알림
    create_notification
  end
  
  def process_status_change
    case status
    when STATUSES[:approved]
      # 승인 알림
      create_notification(type: 'reward_approved')
    when STATUSES[:paid]
      # 지급 알림
      create_notification(type: 'reward_paid')
    when STATUSES[:cancelled]
      # 취소 알림
      create_notification(type: 'reward_cancelled')
    end
  end
  
  def create_notification(type: 'reward_created')
    # 알림 시스템이 있다면 여기서 생성
    # Notification.create!(
    #   user: referrer,
    #   type: type,
    #   data: {
    #     reward_id: id,
    #     amount: credits_amount,
    #     referred_email: referred.email
    #   }
    # )
  end
  
  def format_currency(amount)
    return "₩0" unless amount
    "₩#{amount.to_i.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')}"
  end
end