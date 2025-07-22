# frozen_string_literal: true

# 사용자 활동을 비동기로 추적
class UserActivityTrackingJob < ApplicationJob
  queue_as :low
  
  def perform(user_id:, action:, details:, request_info:, success: true, credits_used: 0)
    user = user_id ? User.find_by(id: user_id) : nil
    
    activity = UserActivity.new(
      user: user,
      action: action,
      details: details,
      success: success,
      credits_used: credits_used,
      started_at: Time.current
    )
    
    # 요청 정보 설정
    if request_info
      activity.ip_address = request_info[:ip_address]
      activity.user_agent = request_info[:user_agent]
      activity.session_id = request_info[:session_id]
      activity.referrer = request_info[:referrer]
    end
    
    # 위치 정보 추출 (IP 기반)
    if activity.ip_address
      activity.location = fetch_location_data(activity.ip_address)
    end
    
    activity.save!
    
    # 실시간 대시보드 업데이트
    broadcast_activity_update(activity)
    
  rescue => e
    Rails.logger.error "Activity tracking failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end
  
  private
  
  def fetch_location_data(ip_address)
    # 개발 환경에서는 기본값 반환
    return default_location if Rails.env.development? || ip_address.in?(['127.0.0.1', '::1'])
    
    # 실제로는 IP 위치 서비스 사용 (예: MaxMind GeoIP2)
    # 여기서는 간단한 예시만
    {
      country: 'KR',
      region: 'Seoul',
      city: 'Seoul',
      timezone: 'Asia/Seoul'
    }
  rescue
    default_location
  end
  
  def default_location
    {
      country: 'Unknown',
      region: 'Unknown',
      city: 'Unknown',
      timezone: 'UTC'
    }
  end
  
  def broadcast_activity_update(activity)
    # ActionCable로 실시간 업데이트 (향후 구현)
    # AdminDashboardChannel.broadcast_to(
    #   'activity_stream',
    #   {
    #     type: 'new_activity',
    #     activity: activity.as_json(include: :user)
    #   }
    # )
  end
end