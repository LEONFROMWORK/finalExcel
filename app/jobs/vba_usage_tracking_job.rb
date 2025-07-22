# frozen_string_literal: true

# VBA 도우미 사용 추적을 비동기로 처리
class VbaUsageTrackingJob < ApplicationJob
  queue_as :low

  def perform(error_type:, solution:, confidence:, match_type:, user_id: nil)
    # 사용 패턴 기록
    VbaUsagePattern.create!(
      error_pattern: error_type,
      solution_used: solution,
      confidence_score: confidence,
      match_type: match_type,
      user_id: user_id,
      was_helpful: false, # 초기값, 피드백으로 업데이트
      metadata: {
        tracked_at: Time.current,
        source: "auto_tracking"
      }
    )

    # 캐시 통계 업데이트
    update_cache_stats(error_type, match_type)

  rescue => e
    Rails.logger.error "VBA usage tracking failed: #{e.message}"
    # 실패해도 사용자 경험에 영향 없음
  end

  private

  def update_cache_stats(error_type, match_type)
    # 오류 타입별 사용 횟수
    Rails.cache.increment("vba_stats:error_type:#{error_type}", 1, expires_in: 7.days)

    # 매치 타입별 통계
    Rails.cache.increment("vba_stats:match_type:#{match_type}", 1, expires_in: 7.days)

    # 일별 사용 통계
    daily_key = "vba_stats:daily:#{Date.current}"
    Rails.cache.increment(daily_key, 1, expires_in: 30.days)
  end
end
