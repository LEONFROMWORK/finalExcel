# frozen_string_literal: true

# 오래된 알림 정리 작업
class CleanupNotificationsJob < ApplicationJob
  queue_as :low

  def perform(days_to_keep = 30)
    deleted_count = Notification.cleanup_old_notifications(days_to_keep)
    Rails.logger.info "Cleaned up #{deleted_count} old notifications"
  end
end
