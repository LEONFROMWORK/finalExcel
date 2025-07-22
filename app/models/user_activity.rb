# frozen_string_literal: true

# 사용자 활동 추적 모델
class UserActivity < ApplicationRecord
  belongs_to :user, optional: true  # 익명 사용자 허용

  # 액션 타입 상수
  ACTIONS = {
    # 인증 관련
    login: "login",
    logout: "logout",
    register: "register",

    # Excel 분석
    excel_upload: "excel_upload",
    excel_analyze: "excel_analyze",
    excel_download: "excel_download",
    excel_error_fix: "excel_error_fix",

    # AI 상담
    ai_chat_start: "ai_chat_start",
    ai_chat_message: "ai_chat_message",
    ai_chat_end: "ai_chat_end",

    # VBA 도우미
    vba_solve: "vba_solve",
    vba_feedback: "vba_feedback",

    # 지식 베이스
    kb_search: "kb_search",
    kb_view: "kb_view",

    # 기타
    page_view: "page_view",
    api_call: "api_call"
  }.freeze

  # 검증
  validates :action, presence: true, inclusion: { in: ACTIONS.values }
  validates :started_at, presence: true
  validates :credits_used, numericality: { greater_than_or_equal_to: 0 }

  # 스코프
  scope :recent, -> { order(started_at: :desc) }
  scope :successful, -> { where(success: true) }
  scope :failed, -> { where(success: false) }
  scope :by_action, ->(action) { where(action: action) }
  scope :by_user, ->(user) { where(user: user) }
  scope :today, -> { where(started_at: Date.current.all_day) }
  scope :this_week, -> { where(started_at: 1.week.ago..Time.current) }
  scope :this_month, -> { where(started_at: 1.month.ago..Time.current) }
  scope :anonymous, -> { where(user_id: nil) }
  scope :authenticated, -> { where.not(user_id: nil) }

  # 콜백
  before_validation :set_started_at
  before_save :detect_device_type
  after_create :update_user_last_activity

  # 클래스 메서드
  class << self
    # 활동 기록
    def track(user: nil, action:, details: {}, request: nil, success: true, credits_used: 0)
      activity = new(
        user: user,
        action: action,
        details: details,
        success: success,
        credits_used: credits_used,
        started_at: Time.current
      )

      # 요청 정보에서 추가 데이터 추출
      if request
        activity.ip_address = request.remote_ip
        activity.user_agent = request.user_agent
        activity.session_id = request.session.id
        activity.referrer = request.referrer
      end

      activity.save!
      activity
    end

    # 활동 종료 기록
    def end_activity(activity_id, success: true, additional_details: {})
      activity = find(activity_id)
      activity.update!(
        ended_at: Time.current,
        success: success,
        details: activity.details.merge(additional_details),
        response_time: calculate_response_time(activity.started_at)
      )
    end

    # 통계 데이터
    def statistics(period: :today)
      activities = case period
      when :today then today
      when :week then this_week
      when :month then this_month
      else all
      end

      {
        total_activities: activities.count,
        unique_users: activities.select(:user_id).distinct.count,
        anonymous_activities: activities.anonymous.count,
        actions_breakdown: activities.group(:action).count,
        success_rate: calculate_success_rate(activities),
        avg_response_time: activities.average(:response_time),
        total_credits_used: activities.sum(:credits_used),
        device_breakdown: activities.group(:device_type).count,
        peak_hours: calculate_peak_hours(activities),
        top_users: calculate_top_users(activities)
      }
    end

    # 사용자별 통계
    def user_statistics(user)
      activities = by_user(user)

      {
        total_activities: activities.count,
        actions_breakdown: activities.group(:action).count,
        success_rate: calculate_success_rate(activities),
        total_credits_used: activities.sum(:credits_used),
        avg_session_duration: calculate_avg_session_duration(activities),
        last_activity: activities.maximum(:started_at),
        favorite_features: calculate_favorite_features(activities)
      }
    end

    # 실시간 활동 스트림
    def active_now(threshold: 5.minutes)
      where("started_at > ?", threshold.ago)
        .includes(:user)
        .recent
    end

    private

    def calculate_response_time(started_at)
      ((Time.current - started_at) * 1000).round(2)  # milliseconds
    end

    def calculate_success_rate(activities)
      return 0 if activities.count.zero?
      (activities.successful.count.to_f / activities.count * 100).round(2)
    end

    def calculate_peak_hours(activities)
      activities.group_by { |a| a.started_at.hour }
                .transform_values(&:count)
                .sort_by { |_, count| -count }
                .first(5)
                .to_h
    end

    def calculate_top_users(activities, limit = 10)
      activities.authenticated
                .group(:user_id)
                .count
                .sort_by { |_, count| -count }
                .first(limit)
                .map { |user_id, count| { user_id: user_id, activity_count: count } }
    end

    def calculate_avg_session_duration(activities)
      sessions = activities.where.not(ended_at: nil)
      return 0 if sessions.empty?

      durations = sessions.map { |a| a.ended_at - a.started_at }
      (durations.sum / durations.size).round
    end

    def calculate_favorite_features(activities)
      activities.group(:action)
                .count
                .sort_by { |_, count| -count }
                .first(3)
                .to_h
    end
  end

  # 인스턴스 메서드
  def duration
    return nil unless ended_at
    ended_at - started_at
  end

  def duration_in_seconds
    duration&.to_i
  end

  def anonymous?
    user_id.nil?
  end

  def authenticated?
    user_id.present?
  end

  # 위치 정보 파싱
  def country
    location["country"]
  end

  def city
    location["city"]
  end

  def region
    location["region"]
  end

  private

  def set_started_at
    self.started_at ||= Time.current
  end

  def detect_device_type
    return unless user_agent.present?

    self.device_type = case user_agent.downcase
    when /mobile|android|iphone/ then "mobile"
    when /tablet|ipad/ then "tablet"
    else "desktop"
    end
  end

  def update_user_last_activity
    return unless user

    user.update_columns(
      last_activity_at: started_at,
      last_ip_address: ip_address
    ) if user.respond_to?(:last_activity_at)
  end
end
