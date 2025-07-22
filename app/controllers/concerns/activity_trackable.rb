# frozen_string_literal: true

# 컨트롤러에서 사용자 활동을 추적하는 concern
module ActivityTrackable
  extend ActiveSupport::Concern
  
  included do
    # 특정 액션에서만 추적하려면 only/except 옵션 사용
    # after_action :track_activity, only: [:create, :update, :destroy]
  end
  
  private
  
  def track_activity(action: nil, details: {}, success: true, credits_used: 0)
    return unless should_track_activity?
    
    # 액션 이름 자동 감지
    action ||= "#{controller_name}_#{action_name}"
    
    # 활동 기록 (비동기)
    UserActivityTrackingJob.perform_later(
      user_id: current_user&.id,
      action: action,
      details: build_activity_details(details),
      request_info: extract_request_info,
      success: success,
      credits_used: credits_used
    )
  rescue => e
    Rails.logger.error "Activity tracking failed: #{e.message}"
    # 추적 실패가 메인 요청에 영향을 주지 않도록
  end
  
  def track_api_response
    # API 응답 후 자동 추적
    return unless request.format.json?
    
    success = response.successful?
    credits = @credits_used || 0
    
    track_activity(
      action: "api_#{controller_name}_#{action_name}",
      details: {
        status_code: response.status,
        response_time: response.headers['X-Runtime']
      },
      success: success,
      credits_used: credits
    )
  end
  
  def should_track_activity?
    # 추적 조건 설정
    return false if controller_name == 'health' # 헬스체크 제외
    return false if action_name.in?(['options', 'head']) # OPTIONS, HEAD 요청 제외
    
    true
  end
  
  def build_activity_details(custom_details = {})
    {
      controller: controller_name,
      action: action_name,
      params: filtered_params,
      timestamp: Time.current,
      **custom_details
    }
  end
  
  def extract_request_info
    {
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      session_id: session.id.to_s,
      referrer: request.referrer,
      method: request.method,
      path: request.path,
      format: request.format.to_s
    }
  end
  
  def filtered_params
    # 민감한 정보 제거
    params.except(:password, :password_confirmation, :token, :api_key)
          .permit!
          .to_h
  end
  
  # 특정 액션용 헬퍼 메서드
  def track_excel_upload(file_id, success)
    track_activity(
      action: UserActivity::ACTIONS[:excel_upload],
      details: { file_id: file_id },
      success: success
    )
  end
  
  def track_ai_chat(session_id, message_count, credits)
    track_activity(
      action: UserActivity::ACTIONS[:ai_chat_message],
      details: { 
        session_id: session_id,
        message_count: message_count 
      },
      credits_used: credits
    )
  end
  
  def track_vba_solve(error_type, solution_confidence)
    track_activity(
      action: UserActivity::ACTIONS[:vba_solve],
      details: { 
        error_type: error_type,
        confidence: solution_confidence 
      }
    )
  end
end