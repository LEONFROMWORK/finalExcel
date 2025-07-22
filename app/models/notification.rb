# frozen_string_literal: true

# 사용자 알림 모델
class Notification < ApplicationRecord
  belongs_to :user

  # 알림 타입
  TYPES = {
    referral_reward: "ReferralRewardNotification",
    credit_transaction: "CreditTransactionNotification",
    system_announcement: "SystemAnnouncementNotification",
    subscription_reminder: "SubscriptionReminderNotification",
    vba_solution: "VbaSolutionNotification",
    ai_consultation: "AiConsultationNotification"
  }.freeze

  # 우선순위
  PRIORITIES = {
    low: "low",
    normal: "normal",
    high: "high",
    urgent: "urgent"
  }.freeze

  # 검증
  validates :type, presence: true, inclusion: { in: TYPES.values }
  validates :title, presence: true
  validates :priority, inclusion: { in: PRIORITIES.values }

  # 스코프
  scope :unread, -> { where(read: false) }
  scope :read, -> { where(read: true) }
  scope :recent, -> { order(created_at: :desc) }
  scope :unexpired, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }
  scope :by_priority, -> { order(Arel.sql("CASE priority WHEN 'urgent' THEN 0 WHEN 'high' THEN 1 WHEN 'normal' THEN 2 WHEN 'low' THEN 3 END")) }

  # 콜백
  after_create :send_push_notification
  after_create :send_email_notification

  # 클래스 메서드
  class << self
    def unread_count_for(user)
      user.notifications.unread.unexpired.count
    end

    def mark_all_as_read(user)
      user.notifications.unread.update_all(read: true, read_at: Time.current)
    end

    def cleanup_old_notifications(days_to_keep = 30)
      where("created_at < ?", days_to_keep.days.ago).destroy_all
    end
  end

  # 인스턴스 메서드
  def mark_as_read!
    return if read?

    update!(read: true, read_at: Time.current)
  end

  def expired?
    expires_at.present? && expires_at < Time.current
  end

  def actionable?
    action_url.present?
  end

  private

  def send_push_notification
    return unless user.push_notifications_enabled?
    nil if priority == "low"

    # Push 알림 서비스 구현 시
    # PushNotificationService.new(user).send_notification(self)
  end

  def send_email_notification
    return unless should_send_email?

    # 이메일 발송 작업 예약
    NotificationMailerJob.perform_later(self)
  end

  def should_send_email?
    user.email_notifications_enabled? &&
      priority.in?(%w[high urgent]) &&
      !user.recently_notified_by_email?
  end
end

# STI 서브클래스들
class ReferralRewardNotification < Notification
  def self.create_for_signup_reward(reward)
    create!(
      user: reward.referrer,
      title: "추천 가입 보상 획득!",
      content: "#{reward.referred.name}님이 회원가입을 완료했습니다. #{reward.credits_amount} 크레딧을 획득했습니다!",
      data: {
        reward_id: reward.id,
        referred_user_id: reward.referred_id,
        credits_amount: reward.credits_amount
      },
      action_url: "/my-account?tab=referral",
      action_text: "추천 현황 보기",
      priority: "high"
    )
  end

  def self.create_for_purchase_reward(reward)
    create!(
      user: reward.referrer,
      title: "추천 구매 보상 획득!",
      content: "#{reward.referred.name}님이 첫 구매를 완료했습니다. #{reward.credits_amount} 크레딧을 획득했습니다!",
      data: {
        reward_id: reward.id,
        referred_user_id: reward.referred_id,
        credits_amount: reward.credits_amount
      },
      action_url: "/my-account?tab=referral",
      action_text: "추천 현황 보기",
      priority: "high"
    )
  end
end

class CreditTransactionNotification < Notification
  def self.create_for_purchase(transaction)
    create!(
      user: transaction.user,
      title: "크레딧 구매 완료",
      content: "#{transaction.amount} 크레딧이 충전되었습니다.",
      data: {
        transaction_id: transaction.id,
        amount: transaction.amount,
        balance_after: transaction.balance_after
      },
      action_url: "/my-account?tab=credits",
      action_text: "크레딧 내역 보기",
      priority: "normal"
    )
  end

  def self.create_for_low_balance(user)
    create!(
      user: user,
      title: "크레딧 잔액 부족 알림",
      content: "현재 크레딧 잔액이 #{user.credits}개입니다. 서비스 이용을 위해 크레딧을 충전해주세요.",
      data: {
        current_balance: user.credits
      },
      action_url: "/credits/purchase",
      action_text: "크레딧 충전하기",
      priority: "high"
    )
  end
end

class SystemAnnouncementNotification < Notification
  def self.create_for_all_users(title, content, priority = "normal")
    User.active.find_each do |user|
      create!(
        user: user,
        title: title,
        content: content,
        priority: priority,
        expires_at: 30.days.from_now
      )
    end
  end
end

class SubscriptionReminderNotification < Notification
  def self.create_for_expiring_subscription(user)
    create!(
      user: user,
      title: "구독 만료 예정",
      content: "구독이 #{user.subscription_expires_at.strftime('%Y년 %m월 %d일')}에 만료됩니다.",
      data: {
        expires_at: user.subscription_expires_at
      },
      action_url: "/my-account?tab=subscription",
      action_text: "구독 갱신하기",
      priority: "high",
      expires_at: user.subscription_expires_at
    )
  end
end

class VbaSolutionNotification < Notification
  def self.create_for_solution_ready(vba_pattern)
    create!(
      user: vba_pattern.user,
      title: "VBA 솔루션 준비 완료",
      content: "요청하신 VBA 오류 '#{vba_pattern.error_message.truncate(50)}'에 대한 해결책이 준비되었습니다.",
      data: {
        vba_pattern_id: vba_pattern.id
      },
      action_url: "/vba/solutions/#{vba_pattern.id}",
      action_text: "솔루션 확인하기",
      priority: "normal"
    )
  end
end

class AiConsultationNotification < Notification
  def self.create_for_new_response(chat_session)
    create!(
      user: chat_session.user,
      title: "AI 상담 답변 도착",
      content: "AI 전문가가 답변을 보냈습니다.",
      data: {
        chat_session_id: chat_session.id
      },
      action_url: "/consultations/#{chat_session.id}",
      action_text: "답변 확인하기",
      priority: "normal"
    )
  end
end
