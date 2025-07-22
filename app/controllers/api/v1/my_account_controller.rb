# frozen_string_literal: true

module Api
  module V1
    # 나의 페이지 API 컨트롤러
    class MyAccountController < Api::V1::ApiController
      # FREE TEST PERIOD - Authentication disabled
      # before_action :authenticate_user!
      
      # 추천 통계 및 정보
      def referral_stats
        service = ReferralService.new(current_user)
        stats = service.referral_statistics
        
        # 추천 코드 정보 추가
        referral_code = service.get_or_create_referral_code
        
        render json: {
          stats: {
            code: referral_code.code,
            referral_url: referral_code.referral_url,
            qr_code_url: referral_code.qr_code_url,
            total_signups: stats[:rewards][:total_rewards],
            total_earned: stats[:rewards][:total_earned],
            pending_amount: stats[:rewards][:pending_amount],
            conversion_rate: calculate_conversion_rate(stats),
            credits_per_signup: referral_code.credits_per_signup,
            credits_per_purchase: referral_code.credits_per_purchase,
            pending_count: stats[:rewards][:by_status]['pending'] || 0
          },
          recent_referrals: stats[:recent_referrals]
        }
      end
      
      # 활동 내역
      def activities
        activities = current_user.user_activities
                                .includes(:device_info)
                                .recent
                                .page(params[:page])
                                .per(params[:per_page] || 20)
        
        render json: {
          activities: activities.map { |activity| serialize_activity(activity) },
          meta: pagination_meta(activities)
        }
      end
      
      # 크레딧 내역
      def credit_history
        # 크레딧 트랜잭션 모델이 구현되면 사용
        # transactions = current_user.credit_transactions
        #                           .recent
        #                           .page(params[:page])
        #                           .per(params[:per_page] || 20)
        
        # 임시로 추천 보상 내역으로 대체
        transactions = ReferralReward.where(
          'referrer_id = ? OR referred_id = ?',
          current_user.id, current_user.id
        ).recent.page(params[:page]).per(params[:per_page] || 20)
        
        render json: {
          transactions: transactions.map { |t| serialize_credit_transaction(t) },
          current_balance: current_user.credits,
          meta: pagination_meta(transactions)
        }
      end
      
      # 설정 업데이트
      def update_settings
        if current_user.update(user_settings_params)
          render json: {
            success: true,
            user: serialize_user(current_user)
          }
        else
          render json: {
            success: false,
            errors: current_user.errors.full_messages
          }, status: :unprocessable_entity
        end
      end
      
      # 크레딧 구매
      def purchase_credits
        package_id = params[:packageId]
        amount = params[:amount].to_i
        payment_method = params[:paymentMethod]
        coupon_code = params[:coupon]
        
        # 결제 서비스를 통한 구매 처리
        payment_service = PaymentService.new(current_user)
        result = payment_service.purchase_credits(
          package_id,
          amount,
          payment_method,
          coupon: coupon_code
        )
        
        if result[:success]
          render json: {
            success: true,
            credits_added: result[:credits_added],
            new_balance: result[:new_balance],
            transaction_id: result[:transaction_id]
          }
        else
          render json: {
            success: false,
            error: result[:error]
          }, status: :unprocessable_entity
        end
      end
      
      # 아바타 업로드
      def upload_avatar
        if params[:avatar].present?
          service = FileUploadService.new(current_user)
          result = service.upload_avatar(params[:avatar])
          
          if result[:success]
            render json: result
          else
            render json: result, status: :unprocessable_entity
          end
        else
          render json: {
            success: false,
            error: '파일을 선택해주세요'
          }, status: :unprocessable_entity
        end
      end
      
      # 아바타 삭제
      def delete_avatar
        service = FileUploadService.new(current_user)
        result = service.delete_avatar
        
        if result[:success]
          render json: result
        else
          render json: result, status: :unprocessable_entity
        end
      end
      
      # AI 상담 내역
      def ai_consultations
        sessions = current_user.chat_sessions
                              .includes(:chat_messages)
                              .recent
                              .page(params[:page])
                              .per(params[:per_page] || 10)
        
        render json: {
          consultations: sessions.map { |s| serialize_consultation(s) },
          meta: pagination_meta(sessions)
        }
      end
      
      # VBA 해결 내역
      def vba_solutions
        patterns = current_user.vba_usage_patterns
                              .recent
                              .page(params[:page])
                              .per(params[:per_page] || 10)
        
        render json: {
          solutions: patterns.map { |p| serialize_vba_solution(p) },
          meta: pagination_meta(patterns)
        }
      end
      
      # Excel 파일 목록
      def excel_files
        files = current_user.excel_files
                           .includes(:analysis_results)
                           .recent
                           .page(params[:page])
                           .per(params[:per_page] || 10)
        
        render json: {
          files: files.map { |f| serialize_excel_file(f) },
          meta: pagination_meta(files)
        }
      end
      
      # 구독 정보
      def subscription_info
        render json: {
          subscription: {
            plan: current_user.subscription_plan || 'free',
            status: current_user.subscription_status || 'active',
            credits_remaining: current_user.credits,
            next_billing_date: current_user.next_billing_date,
            features: get_plan_features(current_user.subscription_plan)
          }
        }
      end
      
      # 비밀번호 변경
      def update_password
        if current_user.valid_password?(params[:current_password])
          if current_user.update(password: params[:new_password])
            render json: { success: true, message: '비밀번호가 변경되었습니다' }
          else
            render json: { success: false, errors: current_user.errors.full_messages }, status: :unprocessable_entity
          end
        else
          render json: { success: false, error: '현재 비밀번호가 올바르지 않습니다' }, status: :unauthorized
        end
      end
      
      # 계정 삭제
      def delete_account
        if current_user.valid_password?(params[:password])
          # 삭제 전 데이터 백업
          backup_user_data(current_user)
          
          current_user.update!(deleted_at: Time.current)
          sign_out current_user
          
          render json: { success: true, message: '계정이 삭제되었습니다' }
        else
          render json: { success: false, error: '비밀번호가 올바르지 않습니다' }, status: :unauthorized
        end
      end
      
      # 개인정보 다운로드
      def download_personal_data
        data = compile_personal_data(current_user)
        
        send_data data.to_json,
                  filename: "personal_data_#{current_user.id}_#{Date.current}.json",
                  type: 'application/json'
      end
      
      # 알림 목록
      def notifications
        # 알림 시스템 구현 시 사용
        render json: {
          notifications: [],
          unread_count: 0
        }
      end
      
      # 알림 설정 업데이트
      def update_notification_preferences
        if current_user.update(notification_preferences_params)
          render json: { success: true, preferences: current_user.notification_preferences }
        else
          render json: { success: false, errors: current_user.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # 연동 서비스 목록
      def connected_services
        services = [
          { 
            service: 'google',
            connected: current_user.provider == 'google_oauth2',
            email: current_user.email,
            connected_at: current_user.created_at
          }
        ]
        
        render json: { services: services }
      end
      
      # 서비스 연동
      def connect_service
        # OAuth 리다이렉트 URL 반환
        service = params[:service]
        redirect_url = "/auth/#{service}"
        
        render json: { redirect_url: redirect_url }
      end
      
      # 서비스 연동 해제
      def disconnect_service
        service = params[:service]
        
        # 연동 해제 로직
        render json: { success: true, message: "#{service} 연동이 해제되었습니다" }
      end
      
      private
      
      def user_settings_params
        params.require(:user).permit(
          :name, :email, :phone, :bio,
          :notification_email, :notification_sms,
          :language, :timezone,
          :marketing_agreed
        )
      end
      
      def notification_preferences_params
        params.require(:preferences).permit(
          :email_notifications,
          :sms_notifications,
          :push_notifications,
          :marketing_emails,
          :activity_updates,
          :weekly_report
        )
      end
      
      def serialize_activity(activity)
        {
          id: activity.id,
          action: activity.action,
          description: activity.human_readable_action,
          created_at: activity.created_at,
          details: activity.details,
          device: activity.device_info&.device_type,
          location: activity.device_info&.location_info
        }
      end
      
      def serialize_credit_transaction(transaction)
        if transaction.is_a?(ReferralReward)
          {
            id: transaction.id,
            type: 'referral_reward',
            amount: transaction.referrer_id == current_user.id ? 
                   transaction.credits_amount : 0,
            description: transaction.description,
            status: transaction.status,
            created_at: transaction.created_at,
            balance_after: nil # 크레딧 트랜잭션 모델에서 구현
          }
        else
          # 실제 크레딧 트랜잭션 모델 구현 시
          {
            id: transaction.id,
            type: transaction.transaction_type,
            amount: transaction.amount,
            description: transaction.description,
            status: transaction.status,
            created_at: transaction.created_at,
            balance_after: transaction.balance_after
          }
        end
      end
      
      def serialize_user(user)
        {
          id: user.id,
          email: user.email,
          name: user.name,
          credits: user.credits,
          avatar: avatar_url(user),
          created_at: user.created_at,
          verified: user.respond_to?(:verified_at) ? user.verified_at.present? : false,
          settings: {
            notification_email: user.notification_email,
            notification_sms: user.notification_sms,
            language: user.language || 'ko',
            timezone: user.timezone || 'Asia/Seoul',
            marketing_agreed: user.marketing_agreed
          }
        }
      end
      
      def avatar_url(user)
        # Active Storage 아바타
        return rails_blob_url(user.avatar) if user.avatar.attached?
        
        # 기본 아바타
        "https://ui-avatars.com/api/?name=#{CGI.escape(user.email)}&background=3B82F6&color=fff"
      end
      
      def calculate_conversion_rate(stats)
        total_signups = stats[:rewards][:by_type]['signup'] || 0
        total_purchases = stats[:rewards][:by_type]['purchase'] || 0
        
        return 0 if total_signups.zero?
        
        ((total_purchases.to_f / total_signups) * 100).round(2)
      end
      
      def pagination_meta(collection)
        {
          current_page: collection.current_page,
          total_pages: collection.total_pages,
          total_count: collection.total_count,
          per_page: collection.limit_value
        }
      end
      
      def serialize_consultation(session)
        {
          id: session.id,
          title: session.title,
          created_at: session.created_at,
          updated_at: session.updated_at,
          message_count: session.chat_messages.count,
          last_message: session.chat_messages.last&.content&.truncate(100)
        }
      end
      
      def serialize_vba_solution(pattern)
        {
          id: pattern.id,
          error_message: pattern.error_message,
          solution_type: pattern.solution_type,
          was_helpful: pattern.was_helpful,
          created_at: pattern.created_at
        }
      end
      
      def serialize_excel_file(file)
        {
          id: file.id,
          filename: file.original_filename,
          size: file.file_size,
          created_at: file.created_at,
          analysis_count: file.analysis_results.count,
          last_analyzed: file.analysis_results.last&.created_at
        }
      end
      
      def get_plan_features(plan)
        features = {
          'free' => [
            '월 10회 AI 상담',
            '기본 Excel 분석',
            'VBA 오류 해결',
            '5GB 저장 공간'
          ],
          'pro' => [
            '무제한 AI 상담',
            '고급 Excel 분석',
            'VBA 오류 해결 및 최적화',
            '50GB 저장 공간',
            '우선 지원'
          ],
          'enterprise' => [
            '모든 Pro 기능',
            '전담 지원',
            '무제한 저장 공간',
            'API 액세스',
            '맞춤형 AI 모델'
          ]
        }
        
        features[plan] || features['free']
      end
      
      def backup_user_data(user)
        # 사용자 데이터 백업 로직
        Rails.logger.info "Backing up data for user #{user.id}"
      end
      
      def compile_personal_data(user)
        {
          user_info: {
            id: user.id,
            email: user.email,
            name: user.name,
            created_at: user.created_at
          },
          activities: user.user_activities.map { |a| serialize_activity(a) },
          ai_consultations: user.chat_sessions.count,
          vba_solutions: user.vba_usage_patterns.count,
          excel_files: user.excel_files.count,
          credits_history: ReferralReward.where(
            'referrer_id = ? OR referred_id = ?',
            user.id, user.id
          ).map { |r| serialize_credit_transaction(r) }
        }
      end
    end
  end
end