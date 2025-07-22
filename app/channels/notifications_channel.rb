# frozen_string_literal: true

# 실시간 알림 채널
class NotificationsChannel < ApplicationCable::Channel
  def subscribed
    stream_for current_user

    # 구독 시 읽지 않은 알림 수 전송
    transmit(unread_count: Notification.unread_count_for(current_user))
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end

  # 알림 읽음 처리
  def mark_as_read(data)
    notification_service = NotificationService.new(current_user)
    notification_service.mark_as_read(data["notification_id"])
  end

  # 모든 알림 읽음 처리
  def mark_all_as_read
    notification_service = NotificationService.new(current_user)
    notification_service.mark_all_as_read
  end
end
