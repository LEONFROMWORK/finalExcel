# frozen_string_literal: true

# 알림 이메일 발송 작업
class NotificationMailerJob < ApplicationJob
  queue_as :mailers
  
  def perform(notification)
    return unless notification.user.email_notifications_enabled?
    
    # 중복 발송 방지
    return if notification.data['email_sent']
    
    NotificationMailer.notification_email(notification).deliver_now
    
    # 이메일 발송 표시
    notification.data['email_sent'] = true
    notification.data['email_sent_at'] = Time.current
    notification.save!
  rescue StandardError => e
    Rails.logger.error "Failed to send notification email: #{e.message}"
    raise
  end
end