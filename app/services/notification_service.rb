# frozen_string_literal: true

# 알림 서비스
class NotificationService
  attr_reader :user

  def initialize(user)
    @user = user
  end

  # 추천 보상 알림
  def send_referral_reward_notification(reward)
    notification = case reward.reward_type
    when "signup"
      ReferralRewardNotification.create_for_signup_reward(reward)
    when "purchase"
      ReferralRewardNotification.create_for_purchase_reward(reward)
    else
      create_generic_reward_notification(reward)
    end

    broadcast_notification(notification) if notification.persisted?
  end

  # 크레딧 거래 알림
  def send_credit_notification(transaction)
    return unless should_notify_credit_transaction?(transaction)

    notification = case transaction.transaction_type
    when "purchase"
      CreditTransactionNotification.create_for_purchase(transaction)
    when "usage"
      check_and_notify_low_balance
    else
      create_generic_credit_notification(transaction)
    end

    broadcast_notification(notification) if notification&.persisted?
  end

  # 실시간 알림 브로드캐스트
  def broadcast_notification(notification)
    # ActionCable을 통한 실시간 알림
    NotificationsChannel.broadcast_to(
      user,
      {
        notification: serialize_notification(notification),
        unread_count: Notification.unread_count_for(user)
      }
    )
  end

  # 알림 읽음 처리
  def mark_as_read(notification_id)
    notification = user.notifications.find(notification_id)
    notification.mark_as_read!

    broadcast_unread_count
  end

  # 모든 알림 읽음 처리
  def mark_all_as_read
    Notification.mark_all_as_read(user)
    broadcast_unread_count
  end

  # 알림 삭제
  def delete_notification(notification_id)
    user.notifications.find(notification_id).destroy
    broadcast_unread_count
  end

  # 알림 목록 조회
  def notifications(page: 1, per_page: 20, unread_only: false)
    scope = user.notifications.unexpired
    scope = scope.unread if unread_only

    notifications = scope.by_priority
                        .recent
                        .page(page)
                        .per(per_page)

    {
      notifications: notifications.map { |n| serialize_notification(n) },
      meta: {
        current_page: notifications.current_page,
        total_pages: notifications.total_pages,
        total_count: notifications.total_count,
        unread_count: Notification.unread_count_for(user)
      }
    }
  end

  # 알림 설정 업데이트
  def update_preferences(preferences)
    user.update!(
      email_notifications_enabled: preferences[:email],
      push_notifications_enabled: preferences[:push],
      notification_categories: preferences[:categories] || []
    )
  end

  # 시스템 공지 생성
  def self.broadcast_system_announcement(title, content, priority: "normal")
    SystemAnnouncementNotification.create_for_all_users(title, content, priority)
  end

  # 구독 만료 알림 (배치 작업용)
  def self.send_subscription_reminders
    User.with_expiring_subscriptions.find_each do |user|
      SubscriptionReminderNotification.create_for_expiring_subscription(user)
    end
  end

  private

  def should_notify_credit_transaction?(transaction)
    # 중요한 거래만 알림
    transaction.amount.abs >= 100 ||
      transaction.transaction_type.in?(%w[purchase refund])
  end

  def check_and_notify_low_balance
    return if user.credits > 50
    return if user.notifications
                  .where(type: "CreditTransactionNotification")
                  .where("created_at > ?", 1.day.ago)
                  .exists?

    CreditTransactionNotification.create_for_low_balance(user)
  end

  def create_generic_reward_notification(reward)
    user.notifications.create!(
      type: "ReferralRewardNotification",
      title: "추천 보상 획득",
      content: "#{reward.credits_amount} 크레딧을 획득했습니다.",
      data: { reward_id: reward.id },
      priority: "normal"
    )
  end

  def create_generic_credit_notification(transaction)
    return unless transaction.credit_in?

    user.notifications.create!(
      type: "CreditTransactionNotification",
      title: "크레딧 획득",
      content: "#{transaction.amount} 크레딧을 획득했습니다.",
      data: { transaction_id: transaction.id },
      priority: "low"
    )
  end

  def serialize_notification(notification)
    {
      id: notification.id,
      type: notification.type,
      title: notification.title,
      content: notification.content,
      read: notification.read,
      read_at: notification.read_at,
      created_at: notification.created_at,
      priority: notification.priority,
      action_url: notification.action_url,
      action_text: notification.action_text,
      data: notification.data
    }
  end

  def broadcast_unread_count
    NotificationsChannel.broadcast_to(
      user,
      {
        unread_count: Notification.unread_count_for(user)
      }
    )
  end
end
