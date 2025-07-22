# frozen_string_literal: true

# 구독 만료 알림 발송 작업
class SendSubscriptionRemindersJob < ApplicationJob
  queue_as :mailers
  
  def perform
    NotificationService.send_subscription_reminders
  end
end