# frozen_string_literal: true

# 이미지 변형 처리 작업
class ProcessImageVariantsJob < ApplicationJob
  queue_as :low

  def perform(user)
    return unless user.avatar.attached?

    # 썸네일 생성
    user.avatar.variant(:thumb).processed

    # 중간 크기 생성
    user.avatar.variant(:medium).processed
  rescue => e
    Rails.logger.error "Failed to process image variants for user #{user.id}: #{e.message}"
  end
end
