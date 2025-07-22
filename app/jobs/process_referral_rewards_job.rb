# frozen_string_literal: true

# 추천인 보상 자동 처리 작업
class ProcessReferralRewardsJob < ApplicationJob
  queue_as :default

  def perform
    # 7일 이상 대기 중인 추천 보상 자동 승인
    process_pending_signup_rewards

    # 구매 관련 보상 처리
    process_pending_purchase_rewards

    # 만료된 추천 코드 비활성화
    deactivate_expired_codes

    # 통계 업데이트
    update_referral_statistics
  end

  private

  def process_pending_signup_rewards
    # 7일 이상 대기 중인 가입 보상
    pending_rewards = ReferralReward.pending
                                   .where(reward_type: "signup")
                                   .where("created_at <= ?", 7.days.ago)

    pending_rewards.find_each do |reward|
      begin
        # 부정 가입 체크
        next if suspicious_signup?(reward.referred)

        # 보상 승인 및 지급
        if reward.approve_and_pay!
          Rails.logger.info "Approved referral reward ##{reward.id} for user ##{reward.referrer_id}"

          # 알림 전송 (알림 시스템 구현 시)
          # NotificationService.new(reward.referrer).send_referral_reward_notification(reward)
        end
      rescue => e
        Rails.logger.error "Failed to process reward ##{reward.id}: #{e.message}"
      end
    end
  end

  def process_pending_purchase_rewards
    # 3일 이상 대기 중인 구매 보상
    pending_rewards = ReferralReward.pending
                                   .where(reward_type: "purchase")
                                   .where("created_at <= ?", 3.days.ago)

    pending_rewards.find_each do |reward|
      begin
        # 환불 여부 체크
        next if purchase_refunded?(reward)

        # 보상 승인 및 지급
        if reward.approve_and_pay!
          Rails.logger.info "Approved purchase reward ##{reward.id} for user ##{reward.referrer_id}"
        end
      rescue => e
        Rails.logger.error "Failed to process purchase reward ##{reward.id}: #{e.message}"
      end
    end
  end

  def deactivate_expired_codes
    expired_codes = ReferralCode.active
                                .where("expires_at < ?", Time.current)

    expired_codes.update_all(is_active: false)

    Rails.logger.info "Deactivated #{expired_codes.count} expired referral codes"
  end

  def update_referral_statistics
    # 활성 추천 코드별 통계 업데이트
    ReferralCode.active.find_each do |code|
      stats = code.statistics

      # 캐시에 저장 (Redis 사용 시)
      Rails.cache.write(
        "referral_stats:#{code.id}",
        stats,
        expires_in: 1.hour
      )
    end
  end

  def suspicious_signup?(user)
    # 부정 가입 감지 로직
    # 1. 같은 IP에서 짧은 시간 내 다수 가입
    recent_signups_from_ip = User.where(current_sign_in_ip: user.current_sign_in_ip)
                                 .where("created_at > ?", 1.hour.ago)
                                 .count

    return true if recent_signups_from_ip > 3

    # 2. 이메일 패턴 체크 (일회용 이메일 등)
    disposable_domains = %w[tempmail.com guerrillamail.com mailinator.com]
    email_domain = user.email.split("@").last

    return true if disposable_domains.include?(email_domain)

    # 3. 활동 없는 계정 (가입 후 7일간 활동 없음)
    if user.created_at < 7.days.ago
      return true if user.user_activities.count == 0
    end

    false
  end

  def purchase_refunded?(reward)
    # 구매 거래가 환불되었는지 확인
    transaction_id = reward.metadata["transaction_id"]
    return false unless transaction_id

    CreditTransaction.exists?(
      payment_transaction_id: transaction_id,
      status: "refunded"
    )
  end
end
