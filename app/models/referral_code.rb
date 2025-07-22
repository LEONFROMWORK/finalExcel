# frozen_string_literal: true

# 추천인 코드 모델
class ReferralCode < ApplicationRecord
  belongs_to :user
  has_many :referral_rewards, dependent: :destroy

  # 추천인 타입
  REFERRAL_TYPES = {
    general: "general",      # 일반 사용자 추천
    special: "special",      # 특별 프로모션
    partner: "partner",      # 파트너 추천
    influencer: "influencer" # 인플루언서
  }.freeze

  # 검증
  validates :code, presence: true, uniqueness: { case_sensitive: false }
  validates :credits_per_signup, numericality: { greater_than_or_equal_to: 0 }
  validates :credits_per_purchase, numericality: { greater_than_or_equal_to: 0 }
  validates :referral_type, inclusion: { in: REFERRAL_TYPES.values }

  # 스코프
  scope :active, -> { where(is_active: true) }
  scope :valid, -> { active.where("expires_at IS NULL OR expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at < ?", Time.current) }
  scope :available, -> { valid.where("max_uses IS NULL OR usage_count < max_uses") }

  # 콜백
  before_validation :generate_code, on: :create
  before_validation :set_defaults

  # 클래스 메서드
  class << self
    # 추천 URL 생성
    def generate_referral_url(code, base_url = nil)
      base_url ||= Rails.application.config.app_host || "https://excel-unified.com"
      "#{base_url}/signup?ref=#{code}"
    end

    # 코드로 찾기 (대소문자 구분 없음)
    def find_by_code(code)
      find_by("LOWER(code) = ?", code.downcase)
    end

    # 사용 가능한 코드인지 확인
    def valid_code?(code)
      referral_code = find_by_code(code)
      referral_code&.can_be_used?
    end
  end

  # 인스턴스 메서드

  # 추천 URL
  def referral_url(base_url = nil)
    self.class.generate_referral_url(code, base_url)
  end

  # QR 코드 URL
  def qr_code_url
    "https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=#{CGI.escape(referral_url)}"
  end

  # 사용 가능 여부
  def can_be_used?
    return false unless is_active?
    return false if expired?
    return false if max_reached?
    true
  end

  # 만료 여부
  def expired?
    expires_at.present? && expires_at < Time.current
  end

  # 사용 한도 도달 여부
  def max_reached?
    max_uses.present? && usage_count >= max_uses
  end

  # 남은 사용 횟수
  def remaining_uses
    return nil unless max_uses
    [ max_uses - usage_count, 0 ].max
  end

  # 코드 사용
  def use!(referred_user)
    return false unless can_be_used?

    transaction do
      # 사용 횟수 증가
      increment!(:usage_count)

      # 회원가입 보상 생성
      create_signup_reward(referred_user)

      # 활동 기록
      UserActivity.track(
        user: referred_user,
        action: "referral_signup",
        details: {
          referral_code: code,
          referrer_id: user_id
        }
      )

      true
    end
  rescue => e
    Rails.logger.error "Referral code usage failed: #{e.message}"
    false
  end

  # 구매 보상 처리
  def process_purchase_reward(referred_user, purchase_amount)
    return unless credits_per_purchase > 0

    # 보상 계산 (구매 금액의 %)
    reward_amount = if settings["purchase_percentage"]
                     purchase_amount * (settings["purchase_percentage"] / 100.0)
    else
                     credits_per_purchase
    end

    referral_rewards.create!(
      referrer_id: user_id,
      referred_id: referred_user.id,
      reward_type: "purchase",
      credits_amount: reward_amount,
      status: "pending",
      metadata: {
        purchase_amount: purchase_amount,
        timestamp: Time.current
      }
    )
  end

  # 통계
  def statistics
    rewards = referral_rewards

    {
      total_signups: rewards.where(reward_type: "signup").count,
      total_purchases: rewards.where(reward_type: "purchase").count,
      total_rewards_paid: rewards.where(status: "paid").sum(:credits_amount),
      pending_rewards: rewards.where(status: "pending").sum(:credits_amount),
      conversion_rate: calculate_conversion_rate,
      top_referrals: top_referrals(5)
    }
  end

  private

  def generate_code
    return if code.present?

    # 사용자 정의 코드가 없으면 자동 생성
    loop do
      self.code = case referral_type
      when "partner" then "PARTNER_#{generate_random_code(6)}"
      when "influencer" then "INF_#{generate_random_code(6)}"
      when "special" then "SPECIAL_#{generate_random_code(8)}"
      else generate_user_friendly_code
      end

      break unless self.class.exists?(code: code)
    end
  end

  def generate_random_code(length = 8)
    SecureRandom.alphanumeric(length).upcase
  end

  def generate_user_friendly_code
    # 사용자 이름 기반 + 랜덤
    base = user.email.split("@").first.gsub(/[^a-zA-Z0-9]/, "")[0..3].upcase
    "#{base}#{generate_random_code(4)}"
  end

  def set_defaults
    self.referral_type ||= "general"
    self.settings ||= {}
  end

  def create_signup_reward(referred_user)
    referral_rewards.create!(
      referrer_id: user_id,
      referred_id: referred_user.id,
      reward_type: "signup",
      credits_amount: credits_per_signup,
      status: "pending",
      metadata: {
        signup_date: referred_user.created_at,
        ip_address: referred_user.current_sign_in_ip
      }
    )
  end

  def calculate_conversion_rate
    return 0 if usage_count.zero?

    purchases = referral_rewards.where(reward_type: "purchase").count
    (purchases.to_f / usage_count * 100).round(2)
  end

  def top_referrals(limit)
    referral_rewards
      .joins("JOIN users ON users.id = referral_rewards.referred_id")
      .select("users.email, users.id, SUM(referral_rewards.credits_amount) as total_rewards")
      .where(status: "paid")
      .group("users.id, users.email")
      .order("total_rewards DESC")
      .limit(limit)
  end
end
