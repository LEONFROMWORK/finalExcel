# frozen_string_literal: true

module Api
  module V1
    module Admin
      class DataCollectionController < Api::V1::ApiController
        # FREE TEST PERIOD - No authentication required
        # before_action :authenticate_admin!

        def index
          # Get all collection tasks with stats
          tasks = DataPipeline::CollectionTask.includes(:collection_runs).all
          
          render json: {
            platforms: available_platforms,
            tasks: serialize_tasks(tasks)
          }
        end

        def create_task
          # Create a new collection task for selected platforms
          platforms = params[:platforms] || []
          platforms = platforms & available_platforms.keys # Ensure valid platforms
          
          if platforms.empty?
            render json: { error: '최소 하나의 플랫폼을 선택해주세요' }, status: :unprocessable_entity
            return
          end

          tasks = []
          platforms.each do |platform|
            task = DataPipeline::CollectionTask.create!(
              name: "#{platform.capitalize} Data Collection - #{Time.current.strftime('%Y%m%d')}",
              task_type: 'web_scraping',
              source_config: {
                'url' => platform_config(platform)[:base_url] || platform,
                'platform' => platform,
                'enable_image_analysis' => params[:enable_image_analysis] || false
              },
              schedule_config: {
                'frequency' => params[:frequency] || 'manual',
                'limit' => params[:limit] || 10
              },
              user: current_user,
              enabled: true
            )
            tasks << task
          end

          render json: {
            message: "#{tasks.size}개의 수집 작업이 생성되었습니다",
            tasks: serialize_tasks(tasks)
          }
        end

        def run_collection
          task = DataPipeline::CollectionTask.find(params[:id])
          
          # Create and execute collection run
          collection_service = DataPipeline::Services::CollectionService.new(task)
          run = collection_service.execute
          
          render json: {
            message: '수집이 시작되었습니다',
            run_id: run.id,
            status: run.status
          }
        end

        def run_bulk_collection
          # 다중 플랫폼 동시 수집 - 개별 실패 처리 포함
          platforms = params[:platforms] || []
          platforms = platforms & available_platforms.keys # 유효한 플랫폼만
          limit = params[:limit] || 10
          
          if platforms.empty?
            render json: { error: '최소 하나의 플랫폼을 선택해주세요' }, status: :unprocessable_entity
            return
          end
          
          # BulkCollectionService를 사용하여 동시 수집
          service = DataPipeline::BulkCollectionService.new
          result = service.call(
            platforms: platforms,
            limit: limit,
            user: current_user
          )
          
          if result.success?
            # 부분 성공/전체 성공/전체 실패에 따라 다른 HTTP 상태 코드 반환
            status_code = case result.data[:status]
                         when 'all_succeeded'
                           :ok
                         when 'partial_success'
                           :multi_status  # 207 Multi-Status
                         else
                           :unprocessable_entity
                         end
            
            render json: {
              status: result.data[:status],
              message: result.data[:message],
              summary: result.data[:summary],
              platform_results: result.data[:platform_results],
              failed_platforms: result.data[:failed_platforms]
            }, status: status_code
          else
            render json: { 
              error: result.error,
              message: '다중 플랫폼 수집 중 오류가 발생했습니다'
            }, status: :internal_server_error
          end
        end

        def collection_stats
          # Get collection statistics
          stats = {
            total_qa_pairs: KnowledgeBase::QaPair.count,
            by_source: KnowledgeBase::QaPair.group(:source).count,
            recent_collections: DataPipeline::CollectionRun
              .includes(:collection_task)
              .order(created_at: :desc)
              .limit(10)
              .map { |run| serialize_run(run) },
            platform_stats: {}
          }

          # Add platform-specific stats
          available_platforms.keys.each do |platform|
            stats[:platform_stats][platform] = {
              total: KnowledgeBase::QaPair.where(source: platform).count,
              approved: KnowledgeBase::QaPair.where(source: platform, is_approved: true).count,
              with_images: KnowledgeBase::QaPair.where(source: platform)
                .where("metadata->>'has_images' = ?", 'true').count
            }
          end

          render json: stats
        end

        def download_data
          # Download collected data
          platform = params[:platform]
          format = params[:format] || 'json'
          
          qa_pairs = if platform.present?
                      KnowledgeBase::QaPair.where(source: platform)
                    else
                      KnowledgeBase::QaPair.all
                    end

          case format
          when 'json'
            send_data qa_pairs.to_json(include_embeddings: false),
                     filename: "qa_export_#{Time.current.strftime('%Y%m%d_%H%M%S')}.json",
                     type: 'application/json'
          when 'csv'
            csv_data = generate_csv(qa_pairs)
            send_data csv_data,
                     filename: "qa_export_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv",
                     type: 'text/csv'
          else
            render json: { error: '지원하지 않는 형식입니다' }, status: :unprocessable_entity
          end
        end

        def send_to_rag
          # Send data to RAG AI search system
          platform = params[:platform]
          
          qa_pairs = if platform.present?
                      KnowledgeBase::QaPair.where(source: platform, is_approved: true)
                    else
                      KnowledgeBase::QaPair.where(is_approved: true)
                    end

          # Export to RAG format
          exporter = DataExportService.new
          result = exporter.export_for_rag(qa_pairs)
          
          if result[:success]
            render json: {
              message: "#{result[:count]}개의 Q&A가 RAG 시스템으로 전송되었습니다",
              file_path: result[:file_path]
            }
          else
            render json: { error: result[:error] }, status: :unprocessable_entity
          end
        end

        private

        def authenticate_admin!
          unless current_user&.admin?
            render json: { error: '관리자 권한이 필요합니다' }, status: :forbidden
          end
        end

        def available_platforms
          PlatformDataCollector::PLATFORMS
        end

        def platform_config(platform)
          available_platforms[platform] || {}
        end

        def serialize_tasks(tasks)
          tasks.map do |task|
            {
              id: task.id,
              name: task.name,
              platform: task.source_config['platform'],
              enabled: task.enabled,
              last_run: task.collection_runs.order(created_at: :desc).first&.created_at,
              run_count: task.collection_runs.count,
              success_count: task.collection_runs.where(status: 'completed').count,
              created_at: task.created_at
            }
          end
        end

        def serialize_run(run)
          {
            id: run.id,
            task_name: run.collection_task.name,
            platform: run.collection_task.source_config['platform'],
            status: run.status,
            items_collected: run.result_summary&.dig('items_collected') || 0,
            started_at: run.started_at,
            completed_at: run.completed_at,
            duration: run.completed_at && run.started_at ? 
                     (run.completed_at - run.started_at).round : nil
          }
        end

        def generate_csv(qa_pairs)
          require 'csv'
          
          CSV.generate do |csv|
            csv << ['ID', 'Question', 'Answer', 'Source', 'Tags', 'Quality Score', 'Approved', 'Created At']
            
            qa_pairs.each do |qa|
              csv << [
                qa.id,
                qa.question,
                qa.answer,
                qa.source,
                qa.tags.join(', '),
                qa.quality_score,
                qa.is_approved ? 'Yes' : 'No',
                qa.created_at.strftime('%Y-%m-%d %H:%M:%S')
              ]
            end
          end
        end
      end
    end
  end
end