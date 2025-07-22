# frozen_string_literal: true

module Api
  module V1
    # VBA 오류 해결 도우미 API
    class VbaHelperController < ApiController
      # FREE TEST PERIOD - Authentication is already disabled in ApiController
      # skip_before_action :authenticate_user!, only: [:solve, :common_patterns]
      
      # POST /api/v1/vba/solve
      # VBA 오류에 대한 해결책 제공
      def solve
        helper = PracticalVbaHelper.new
        result = helper.solve(params[:error_description])
        
        # 신뢰도가 낮고 사용자가 로그인했으며 크레딧이 있으면 AI 보조
        if result[:need_ai_help] && current_user&.has_credits?
          result[:ai_suggestion] = get_ai_assistance(params[:error_description])
        end
        
        # 사용 기록 (백그라운드)
        track_usage(result) if result[:success]
        
        render json: {
          success: true,
          data: result,
          timestamp: Time.current
        }
      rescue => e
        Rails.logger.error "VBA Helper error: #{e.message}"
        render json: {
          success: false,
          error: "오류 해결 중 문제가 발생했습니다",
          timestamp: Time.current
        }, status: :internal_server_error
      end
      
      # POST /api/v1/vba/feedback
      # 해결책이 도움이 되었는지 피드백 수집
      def feedback
        pattern = VbaUsagePattern.record_feedback(
          params[:error_type],
          params[:solution_used],
          params[:was_helpful],
          current_user,
          {
            confidence: params[:confidence],
            match_type: params[:match_type],
            feedback_text: params[:feedback_text]
          }
        )
        
        render json: {
          success: true,
          message: params[:was_helpful] ? "감사합니다! 피드백이 기록되었습니다." : "더 나은 해결책을 찾아보겠습니다.",
          pattern_id: pattern.id
        }
      rescue => e
        Rails.logger.error "VBA Feedback error: #{e.message}"
        render json: {
          success: false,
          error: "피드백 저장 중 오류가 발생했습니다"
        }, status: :unprocessable_entity
      end
      
      # GET /api/v1/vba/common_patterns
      # 자주 발생하는 오류 패턴 목록
      def common_patterns
        helper = PracticalVbaHelper.new
        patterns = helper.get_common_patterns
        
        # 캐시에서 성공률 추가
        patterns_with_stats = patterns.map do |pattern|
          pattern.merge(
            success_rate: VbaUsagePattern.success_rate_for(pattern[:key]),
            usage_count: VbaUsagePattern.by_pattern(pattern[:key]).count
          )
        end
        
        render json: {
          success: true,
          patterns: patterns_with_stats,
          total_count: patterns.size
        }
      end
      
      # GET /api/v1/vba/stats
      # VBA 도우미 사용 통계 (인증 필요)
      def stats
        authorize_admin!
        
        stats = VbaUsagePattern.usage_stats
        
        render json: {
          success: true,
          stats: stats,
          generated_at: Time.current
        }
      end
      
      private
      
      def get_ai_assistance(error_description)
        return nil unless current_user.credits > 0
        
        begin
          ai_service = UnifiedAiService.new(:basic)
          
          prompt = <<~PROMPT
            VBA 오류를 간단히 해결해주세요 (한 문장):
            오류: #{error_description}
          PROMPT
          
          response = ai_service.generate_text(
            prompt: prompt,
            max_tokens: 100,
            temperature: 0.3
          )
          
          if response[:success]
            # 크레딧 차감
            current_user.decrement!(:credits, 0.01)
            response[:content]
          else
            nil
          end
        rescue => e
          Rails.logger.error "AI assistance error: #{e.message}"
          nil
        end
      end
      
      def track_usage(result)
        # 비동기로 사용 기록
        VbaUsageTrackingJob.perform_later(
          error_type: result[:error_type],
          solution: result[:solutions]&.first,
          confidence: result[:confidence],
          match_type: result[:match_type],
          user_id: current_user&.id
        ) if result[:error_type].present?
      end
      
      def authorize_admin!
        unless current_user&.admin?
          render json: { error: "관리자 권한이 필요합니다" }, status: :forbidden
        end
      end
    end
  end
end