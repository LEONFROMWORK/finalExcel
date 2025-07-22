# frozen_string_literal: true

# VBA 오류 해결 패턴 사용 추적
class VbaUsagePattern < ApplicationRecord
  belongs_to :user, optional: true  # 익명 사용자 허용

  # 검증
  validates :error_pattern, presence: true
  validates :confidence_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }

  # 스코프
  scope :helpful, -> { where(was_helpful: true) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_pattern, ->(pattern) { where(error_pattern: pattern) }
  scope :high_confidence, -> { where("confidence_score >= ?", 0.7) }

  # 클래스 메서드
  class << self
    # 피드백 기록
    def record_feedback(error_type, solution_used, helpful, user = nil, metadata = {})
      create!(
        error_pattern: error_type,
        solution_used: solution_used,
        was_helpful: helpful,
        user: user,
        confidence_score: metadata[:confidence] || 0.5,
        match_type: metadata[:match_type] || "unknown",
        metadata: metadata
      )

      # 도움이 된 패턴은 우선순위 올리기
      boost_solution_priority(error_type, solution_used) if helpful
    end

    # 해결책 우선순위 증가
    def boost_solution_priority(error_type, solution)
      cache_key = "vba_solution:#{error_type}:#{Digest::MD5.hexdigest(solution.to_s)}"
      Rails.cache.increment(cache_key, 1, expires_in: 30.days)
    end

    # 인기 있는 해결책 가져오기
    def popular_solutions(error_type, limit = 5)
      by_pattern(error_type)
        .helpful
        .group(:solution_used)
        .order("COUNT(*) DESC")
        .limit(limit)
        .pluck(:solution_used)
    end

    # 패턴별 성공률 계산
    def success_rate_for(error_pattern)
      patterns = by_pattern(error_pattern)
      total = patterns.count
      return 0.0 if total.zero?

      helpful_count = patterns.helpful.count
      (helpful_count.to_f / total * 100).round(2)
    end

    # 사용 통계
    def usage_stats
      {
        total_uses: count,
        helpful_count: helpful.count,
        success_rate: count.zero? ? 0 : (helpful.count.to_f / count * 100).round(2),
        most_common_errors: group(:error_pattern)
                           .order("COUNT(*) DESC")
                           .limit(10)
                           .count,
        high_confidence_solutions: high_confidence.helpful.count
      }
    end
  end

  # 인스턴스 메서드
  def success?
    was_helpful?
  end

  def anonymous?
    user_id.nil?
  end
end
