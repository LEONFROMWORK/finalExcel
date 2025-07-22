# frozen_string_literal: true

module Api
  module V1
    # 알림 API 컨트롤러
    class NotificationsController < Api::V1::ApiController
      # FREE TEST PERIOD - Authentication disabled
      # before_action :authenticate_user!
      before_action :set_notification_service
      
      # 알림 목록 조회
      def index
        result = @notification_service.notifications(
          page: params[:page] || 1,
          per_page: params[:per_page] || 20,
          unread_only: params[:unread_only] == 'true'
        )
        
        render json: result
      end
      
      # 읽지 않은 알림 수
      def unread_count
        render json: {
          unread_count: Notification.unread_count_for(current_user)
        }
      end
      
      # 알림 읽음 처리
      def mark_as_read
        @notification_service.mark_as_read(params[:id])
        
        render json: { success: true }
      rescue ActiveRecord::RecordNotFound
        render json: { error: '알림을 찾을 수 없습니다' }, status: :not_found
      end
      
      # 모든 알림 읽음 처리
      def mark_all_as_read
        @notification_service.mark_all_as_read
        
        render json: { success: true }
      end
      
      # 알림 삭제
      def destroy
        @notification_service.delete_notification(params[:id])
        
        render json: { success: true }
      rescue ActiveRecord::RecordNotFound
        render json: { error: '알림을 찾을 수 없습니다' }, status: :not_found
      end
      
      # 알림 설정 조회
      def preferences
        render json: {
          email_notifications: current_user.email_notifications_enabled,
          push_notifications: current_user.push_notifications_enabled,
          categories: current_user.notification_categories || default_categories
        }
      end
      
      # 알림 설정 업데이트
      def update_preferences
        @notification_service.update_preferences(notification_preferences_params)
        
        render json: { success: true }
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.message }, status: :unprocessable_entity
      end
      
      private
      
      def set_notification_service
        @notification_service = NotificationService.new(current_user)
      end
      
      def notification_preferences_params
        params.require(:preferences).permit(
          :email,
          :push,
          categories: []
        )
      end
      
      def default_categories
        %w[referral_rewards credit_transactions system_announcements]
      end
    end
  end
end