# frozen_string_literal: true

module Api
  module V1
    module Admin
      # 관리자 대시보드 API
      class DashboardController < ApiController
        # FREE TEST PERIOD - No authentication required
        # before_action :authenticate_admin!
        
        # GET /api/v1/admin/dashboard/overview
        # 전체 대시보드 개요
        def overview
          render json: {
            success: true,
            data: {
              user_activities: user_activity_summary,
              vector_db_status: vector_db_summary,
              system_health: system_health_check,
              quick_stats: quick_stats
            },
            generated_at: Time.current
          }
        end
        
        # GET /api/v1/admin/dashboard/user_activities
        # 사용자 활동 상세
        def user_activities
          activities = UserActivity.includes(:user)
                                  .recent
                                  .page(params[:page])
                                  .per(params[:per_page] || 20)
          
          render json: {
            success: true,
            data: {
              activities: activities.map(&:as_json),
              pagination: pagination_meta(activities),
              statistics: UserActivity.statistics(period: params[:period]&.to_sym || :today)
            }
          }
        end
        
        # GET /api/v1/admin/dashboard/active_users
        # 현재 활동 중인 사용자
        def active_users
          active_users = UserActivity.active_now(threshold: 5.minutes)
                                    .includes(:user)
          
          render json: {
            success: true,
            data: {
              active_count: active_users.count,
              users: active_users.map do |activity|
                {
                  user_id: activity.user_id,
                  email: activity.user&.email,
                  action: activity.action,
                  started_at: activity.started_at,
                  duration: activity.duration_in_seconds,
                  location: activity.location,
                  device_type: activity.device_type
                }
              end
            }
          }
        end
        
        # GET /api/v1/admin/dashboard/vector_db_status
        # 벡터 DB 변환 상태
        def vector_db_status
          statuses = VectorDbStatus.recent
                                  .page(params[:page])
                                  .per(params[:per_page] || 20)
          
          render json: {
            success: true,
            data: {
              statuses: statuses.map do |status|
                {
                  id: status.id,
                  source: "#{status.source_type}##{status.source_id}",
                  status: status.status,
                  progress: status.progress,
                  success_rate: status.success_rate,
                  items: {
                    total: status.total_items,
                    processed: status.processed_items,
                    failed: status.failed_items
                  },
                  embeddings_created: status.embeddings_created,
                  duration: status.duration_in_minutes,
                  estimated_completion: status.estimated_completion_time
                }
              end,
              pagination: pagination_meta(statuses),
              statistics: VectorDbStatus.dashboard_stats
            }
          }
        end
        
        # GET /api/v1/admin/dashboard/user/:id
        # 특정 사용자 상세 정보
        def user_detail
          user = User.find(params[:id])
          activities = user.user_activities.recent.limit(50)
          
          render json: {
            success: true,
            data: {
              user: {
                id: user.id,
                email: user.email,
                created_at: user.created_at,
                credits: user.credits,
                total_activities: user.user_activities.count
              },
              statistics: UserActivity.user_statistics(user),
              recent_activities: activities.map(&:as_json),
              excel_files: user.excel_files.count,
              ai_sessions: user.chat_sessions.count
            }
          }
        rescue ActiveRecord::RecordNotFound
          render json: { success: false, error: "사용자를 찾을 수 없습니다" }, status: :not_found
        end
        
        # POST /api/v1/admin/dashboard/export
        # 데이터 내보내기
        def export_data
          export_type = params[:type] || 'user_activities'
          format = params[:format] || 'csv'
          period = params[:period] || 'week'
          
          job_id = AdminDataExportJob.perform_later(
            export_type: export_type,
            format: format,
            period: period,
            admin_email: current_user.email
          ).job_id
          
          render json: {
            success: true,
            message: "데이터 내보내기가 시작되었습니다. 완료되면 이메일로 전송됩니다.",
            job_id: job_id
          }
        end
        
        # GET /api/v1/admin/dashboard/realtime_stats
        # 실시간 통계 (WebSocket용)
        def realtime_stats
          render json: {
            success: true,
            data: {
              active_users: UserActivity.active_now.count,
              processing_vectors: VectorDbStatus.processing.count,
              last_5_minutes: {
                activities: UserActivity.where('created_at > ?', 5.minutes.ago).count,
                errors: UserActivity.where('created_at > ? AND success = ?', 5.minutes.ago, false).count
              },
              system_load: {
                cpu_usage: get_cpu_usage,
                memory_usage: get_memory_usage,
                queue_size: get_queue_size
              }
            }
          }
        end
        
        private
        
        def authenticate_admin!
          unless current_user&.admin?
            render json: { error: "관리자 권한이 필요합니다" }, status: :forbidden
          end
        end
        
        def user_activity_summary
          {
            today: UserActivity.today.count,
            this_week: UserActivity.this_week.count,
            active_now: UserActivity.active_now.count,
            by_action: UserActivity.today.group(:action).count,
            success_rate: UserActivity.statistics[:success_rate],
            top_features: UserActivity.today.group(:action).order('count_all DESC').limit(5).count
          }
        end
        
        def vector_db_summary
          {
            total: VectorDbStatus.count,
            processing: VectorDbStatus.processing.count,
            completed_today: VectorDbStatus.completed.where('completed_at >= ?', Date.current).count,
            failed_today: VectorDbStatus.failed.where('created_at >= ?', Date.current).count,
            total_embeddings: VectorDbStatus.sum(:embeddings_created),
            by_source: VectorDbStatus.group(:source_type).count
          }
        end
        
        def system_health_check
          {
            database: check_database_health,
            redis: check_redis_health,
            vector_db: check_vector_db_health,
            storage: check_storage_health
          }
        end
        
        def quick_stats
          {
            total_users: User.count,
            new_users_today: User.where('created_at >= ?', Date.current).count,
            total_excel_files: ExcelFile.count,
            excel_files_today: ExcelFile.where('created_at >= ?', Date.current).count,
            total_qa_pairs: QaPair.count,
            vba_solutions_today: VbaUsagePattern.where('created_at >= ?', Date.current).count
          }
        end
        
        def check_database_health
          ActiveRecord::Base.connection.active?
          { status: 'healthy', response_time: measure_db_response_time }
        rescue
          { status: 'unhealthy', error: 'Database connection failed' }
        end
        
        def check_redis_health
          return { status: 'not_configured' } unless Rails.cache.respond_to?(:redis)
          
          Rails.cache.redis.ping
          { status: 'healthy' }
        rescue
          { status: 'unhealthy', error: 'Redis connection failed' }
        end
        
        def check_vector_db_health
          QaPair.with_embedding.limit(1).count
          { status: 'healthy', total_embeddings: QaPair.with_embedding.count }
        rescue
          { status: 'unhealthy', error: 'Vector DB query failed' }
        end
        
        def check_storage_health
          free_space = `df -h /`.lines[1].split[3].to_i rescue 0
          { status: free_space > 10 ? 'healthy' : 'warning', free_space_gb: free_space }
        end
        
        def measure_db_response_time
          start_time = Time.current
          ActiveRecord::Base.connection.execute("SELECT 1")
          ((Time.current - start_time) * 1000).round(2)
        end
        
        def get_cpu_usage
          # 간단한 CPU 사용률 (실제로는 더 정교한 방법 필요)
          `top -bn1 | grep "Cpu(s)" | sed "s/.*, *\\([0-9.]*\\)%* id.*/\\1/" | awk '{print 100 - $1}'`.strip.to_f rescue 0
        end
        
        def get_memory_usage
          # 메모리 사용률
          `free | grep Mem | awk '{print ($3/$2) * 100.0}'`.strip.to_f rescue 0
        end
        
        def get_queue_size
          # Sidekiq 큐 크기 (Sidekiq 설치 시)
          if defined?(Sidekiq)
            Sidekiq::Queue.new.size
          else
            0
          end
        end
        
        def pagination_meta(collection)
          {
            current_page: collection.current_page,
            total_pages: collection.total_pages,
            total_count: collection.total_count,
            per_page: collection.limit_value
          }
        end
      end
    end
  end
end