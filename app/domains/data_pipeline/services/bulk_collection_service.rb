# frozen_string_literal: true

require_relative '../../../shared/value_objects/result'

module DataPipeline
  ##
  # Service for handling bulk collection across multiple platforms
  # Ensures individual platform failures don't stop other collections
  class BulkCollectionService
    def call(platforms:, limit: 10, user:)
      return Result.failure(errors: ["No platforms specified"]) if platforms.blank?
      
      # 각 플랫폼별 수집 작업 초기화
      collection_results = {}
      collection_tasks = []
      
      # 각 플랫폼에 대한 태스크 생성
      platforms.each do |platform|
        task = CollectionTask.create!(
          name: "#{platform.capitalize} Bulk Collection - #{Time.current.strftime('%Y%m%d %H:%M')}",
          task_type: 'web_scraping',
          schedule: 'manual',
          source_config: {
            'platform' => platform,
            'url' => PlatformDataCollector::PLATFORMS[platform][:base_url]
          },
          status: 'active',
          platform: platform,
          requested_count: limit,
          created_by: user,
          user: user
        )
        collection_tasks << task
        collection_results[platform] = {
          task_id: task.id,
          status: 'pending',
          collected_count: 0,
          error: nil,
          started_at: nil,
          completed_at: nil
        }
      end
      
      # 동시에 모든 플랫폼 수집 실행 (병렬 처리)
      threads = []
      
      platforms.each do |platform|
        threads << Thread.new do
          begin
            Rails.logger.info "[BulkCollection] Starting collection for #{platform}"
            collection_results[platform][:started_at] = Time.current
            
            # 개별 플랫폼 수집 실행
            task = collection_tasks.find { |t| t.platform == platform }
            task.update!(started_at: Time.current)
            
            collector = PlatformDataCollector.new(platform)
            result = collector.collect_data(limit)
            
            if result[:success]
              # 성공 시 결과 업데이트
              collected_count = result[:results]&.size || 0
              task.update!(
                completed_at: Time.current,
                collected_count: collected_count
              )
              
              collection_results[platform].merge!(
                status: 'completed',
                collected_count: collected_count,
                completed_at: Time.current,
                message: result[:message]
              )
              
              Rails.logger.info "[BulkCollection] Completed #{platform}: collected #{collected_count} items"
            else
              # 실패 시 에러 정보 저장
              error_message = result[:error] || "Unknown error"
              
              # API 제한 도달 여부 확인
              is_rate_limit = error_message.include?('rate limit') || 
                            error_message.include?('quota') ||
                            error_message.include?('429')
              
              task.update!(
                status: 'disabled',
                completed_at: Time.current,
                error_message: error_message
              )
              
              collection_results[platform].merge!(
                status: 'failed',
                error: error_message,
                error_type: is_rate_limit ? 'rate_limit' : 'collection_error',
                can_retry: !is_rate_limit,
                completed_at: Time.current
              )
              
              Rails.logger.error "[BulkCollection] Failed #{platform}: #{error_message}"
            end
          rescue => e
            # 예외 발생 시 처리
            Rails.logger.error "[BulkCollection] Exception for #{platform}: #{e.message}"
            Rails.logger.error e.backtrace.first(5).join("\n")
            
            error_message = "Exception: #{e.message}"
            
            task.update!(
              status: 'disabled',
              completed_at: Time.current,
              error_message: error_message
            )
            
            collection_results[platform].merge!(
              status: 'failed',
              error: error_message,
              error_type: 'exception',
              can_retry: true,
              completed_at: Time.current
            )
          end
        end
      end
      
      # 모든 스레드가 완료될 때까지 대기 (최대 5분)
      threads.each { |t| t.join(300) }
      
      # 전체 결과 집계
      total_requested = platforms.size
      successful_platforms = collection_results.values.count { |r| r[:status] == 'completed' }
      failed_platforms = collection_results.values.count { |r| r[:status] == 'failed' }
      total_collected = collection_results.values.sum { |r| r[:collected_count] }
      
      # 실패한 플랫폼 정보
      failed_details = collection_results.select { |_, r| r[:status] == 'failed' }
                                       .transform_values { |r| r.slice(:error, :error_type, :can_retry) }
      
      # 전체 성공/부분 성공/전체 실패 판단
      overall_status = if successful_platforms == total_requested
                        'all_succeeded'
                      elsif successful_platforms > 0
                        'partial_success'
                      else
                        'all_failed'
                      end
      
      Result.success(data: {
        status: overall_status,
        summary: {
          total_platforms: total_requested,
          succeeded: successful_platforms,
          failed: failed_platforms,
          total_collected: total_collected
        },
        platform_results: collection_results,
        failed_platforms: failed_details,
        message: build_summary_message(overall_status, successful_platforms, failed_platforms, total_collected)
      })
    end
    
    private
    
    def build_summary_message(status, succeeded, failed, total_collected)
      case status
      when 'all_succeeded'
        "모든 플랫폼에서 성공적으로 수집되었습니다. (총 #{total_collected}개 항목)"
      when 'partial_success'
        "#{succeeded}개 플랫폼 성공, #{failed}개 플랫폼 실패. (총 #{total_collected}개 항목 수집)"
      when 'all_failed'
        "모든 플랫폼에서 수집이 실패했습니다."
      end
    end
  end
end