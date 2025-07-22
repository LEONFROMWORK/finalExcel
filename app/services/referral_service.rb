# frozen_string_literal: true

# 추천인 시스템 관리 서비스
class ReferralService
  attr_reader :user
  
  def initialize(user)
    @user = user
  end
  
  # 사용자의 추천 코드 생성 또는 조회
  def get_or_create_referral_code
    existing_code = user.referral_codes.active.first
    return existing_code if existing_code
    
    user.referral_codes.create!(
      referral_type: 'general',
      credits_per_signup: default_signup_credits,
      credits_per_purchase: default_purchase_credits
    )
  end
  
  # 추천 코드 검증 및 사용
  def use_referral_code(code, referred_user)
    return { success: false, error: '추천 코드를 입력해주세요' } if code.blank?
    
    referral_code = ReferralCode.find_by_code(code)
    
    unless referral_code
      return { success: false, error: '유효하지 않은 추천 코드입니다' }
    end
    
    unless referral_code.can_be_used?
      return { success: false, error: '사용할 수 없는 추천 코드입니다' }
    end
    
    if referral_code.user_id == referred_user.id
      return { success: false, error: '자신의 추천 코드는 사용할 수 없습니다' }
    end
    
    # 이미 추천받은 사용자인지 확인
    if ReferralReward.exists?(referred_id: referred_user.id, reward_type: 'signup')
      return { success: false, error: '이미 추천 코드를 사용한 계정입니다' }
    end
    
    # 추천 코드 사용
    if referral_code.use!(referred_user)
      { 
        success: true, 
        message: "추천 코드가 적용되었습니다. #{referral_code.credits_per_signup} 크레딧이 추천인에게 지급됩니다.",
        referrer: referral_code.user,
        credits: referral_code.credits_per_signup
      }
    else
      { success: false, error: '추천 코드 처리 중 오류가 발생했습니다' }
    end
  end
  
  # 구매 시 추천 보상 처리
  def process_purchase_reward(referred_user, purchase_amount)
    # 추천받은 사용자인지 확인
    signup_reward = ReferralReward.find_by(
      referred_id: referred_user.id,
      reward_type: 'signup'
    )
    
    return unless signup_reward
    
    referral_code = signup_reward.referral_code
    return unless referral_code.credits_per_purchase > 0
    
    # 첫 구매인지 확인
    existing_purchase = ReferralReward.exists?(
      referred_id: referred_user.id,
      reward_type: 'purchase'
    )
    
    # 첫 구매에만 보상 (설정에 따라 변경 가능)
    unless existing_purchase || referral_code.settings['multiple_purchase_rewards']
      referral_code.process_purchase_reward(referred_user, purchase_amount)
    end
  end
  
  # 추천 통계 조회
  def referral_statistics
    referral_codes = user.referral_codes
    rewards = ReferralReward.by_referrer(user)
    
    {
      referral_codes: {
        total: referral_codes.count,
        active: referral_codes.active.count,
        total_uses: referral_codes.sum(:usage_count)
      },
      rewards: ReferralReward.statistics(user),
      referral_url: get_or_create_referral_code.referral_url,
      qr_code_url: get_or_create_referral_code.qr_code_url,
      recent_referrals: recent_referrals
    }
  end
  
  # 최근 추천 내역
  def recent_referrals(limit = 10)
    ReferralReward.by_referrer(user)
                  .includes(:referred)
                  .recent
                  .limit(limit)
                  .map do |reward|
      {
        id: reward.id,
        referred_email: reward.referred.email,
        reward_type: reward.reward_type,
        credits_amount: reward.credits_amount,
        status: reward.status,
        created_at: reward.created_at,
        description: reward.description
      }
    end
  end
  
  # 특별 추천 코드 생성 (관리자용)
  def create_special_referral_code(params)
    return unless user.admin?
    
    user.referral_codes.create!(
      code: params[:code],
      referral_type: params[:type] || 'special',
      credits_per_signup: params[:signup_credits] || 20,
      credits_per_purchase: params[:purchase_credits] || 10,
      max_uses: params[:max_uses],
      expires_at: params[:expires_at],
      settings: params[:settings] || {}
    )
  end
  
  # 보상 처리 (주기적 작업)
  def self.process_pending_rewards
    ReferralReward.process_pending_rewards
  end
  
  private
  
  def default_signup_credits
    Rails.application.config.referral_signup_credits || 10.0
  end
  
  def default_purchase_credits
    Rails.application.config.referral_purchase_credits || 5.0
  end
end