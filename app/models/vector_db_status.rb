# frozen_string_literal: true

# 벡터 DB 변환 상태 추적
class VectorDbStatus < ApplicationRecord
  # 상태 상수
  STATUSES = {
    pending: 'pending',
    processing: 'processing',
    completed: 'completed',
    failed: 'failed',
    paused: 'paused'
  }.freeze
  
  # 소스 타입
  SOURCE_TYPES = {
    collection_task: 'CollectionTask',
    pipedata_import: 'PipedataImport',
    manual_upload: 'ManualUpload',
    api_import: 'ApiImport'
  }.freeze
  
  # 검증
  validates :source_type, presence: true, inclusion: { in: SOURCE_TYPES.values }
  validates :source_id, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES.values }
  validates :progress, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  
  # 스코프
  scope :pending, -> { where(status: STATUSES[:pending]) }
  scope :processing, -> { where(status: STATUSES[:processing]) }
  scope :completed, -> { where(status: STATUSES[:completed]) }
  scope :failed, -> { where(status: STATUSES[:failed]) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_source, ->(type) { where(source_type: type) }
  
  # 콜백
  before_save :calculate_progress
  after_update :broadcast_status_update
  
  # 클래스 메서드
  class << self
    # 새로운 변환 작업 시작
    def start_conversion(source_type:, source_id:, total_items:, metadata: {})
      create!(
        source_type: source_type,
        source_id: source_id.to_s,
        status: STATUSES[:processing],
        total_items: total_items,
        processed_items: 0,
        failed_items: 0,
        metadata: metadata,
        started_at: Time.current
      )
    end
    
    # 진행 상황 업데이트
    def update_progress(source_type:, source_id:, processed: 0, failed: 0, embeddings: 0)
      status = find_by(source_type: source_type, source_id: source_id.to_s)
      return unless status
      
      status.processed_items += processed
      status.failed_items += failed
      status.embeddings_created += embeddings
      
      # 처리 시간 계산
      if status.started_at && processed > 0
        elapsed_time = (Time.current - status.started_at) * 1000  # ms
        status.avg_processing_time = elapsed_time / status.processed_items
      end
      
      # 완료 체크
      if status.processed_items >= status.total_items
        status.status = STATUSES[:completed]
        status.completed_at = Time.current
      elsif status.failed_items > status.total_items * 0.5  # 50% 이상 실패
        status.status = STATUSES[:failed]
      end
      
      status.save!
    end
    
    # 오류 추가
    def add_error(source_type:, source_id:, error_message:)
      status = find_by(source_type: source_type, source_id: source_id.to_s)
      return unless status
      
      status.error_messages ||= []
      status.error_messages << {
        message: error_message,
        timestamp: Time.current
      }
      status.save!
    end
    
    # 대시보드 통계
    def dashboard_stats
      {
        total_conversions: count,
        active_conversions: processing.count,
        completed_today: completed.where('completed_at >= ?', Date.current).count,
        failed_today: failed.where('created_at >= ?', Date.current).count,
        total_embeddings: sum(:embeddings_created),
        avg_processing_time: average(:avg_processing_time),
        by_source_type: group(:source_type).count,
        recent_activities: recent_activities,
        performance_metrics: performance_metrics
      }
    end
    
    # 최근 활동
    def recent_activities(limit = 10)
      recent.limit(limit).map do |status|
        {
          id: status.id,
          source: "#{status.source_type}##{status.source_id}",
          status: status.status,
          progress: status.progress,
          started_at: status.started_at,
          duration: status.duration_in_minutes,
          embeddings: status.embeddings_created
        }
      end
    end
    
    # 성능 메트릭
    def performance_metrics
      completed_tasks = completed.where('completed_at >= ?', 7.days.ago)
      
      {
        avg_duration: completed_tasks.average('EXTRACT(EPOCH FROM (completed_at - started_at)) / 60'),
        avg_items_per_minute: calculate_avg_items_per_minute(completed_tasks),
        success_rate: calculate_success_rate,
        daily_throughput: calculate_daily_throughput
      }
    end
    
    private
    
    def calculate_avg_items_per_minute(tasks)
      return 0 if tasks.empty?
      
      total_items = tasks.sum(:processed_items)
      total_minutes = tasks.sum('EXTRACT(EPOCH FROM (completed_at - started_at)) / 60')
      
      return 0 if total_minutes.zero?
      (total_items / total_minutes).round(2)
    end
    
    def calculate_success_rate
      total = count
      return 100 if total.zero?
      
      ((completed.count.to_f / total) * 100).round(2)
    end
    
    def calculate_daily_throughput
      last_7_days = 7.days.ago..Time.current
      
      where(started_at: last_7_days)
        .group_by { |s| s.started_at.to_date }
        .transform_values { |statuses| statuses.sum(&:processed_items) }
    end
  end
  
  # 인스턴스 메서드
  def pending?
    status == STATUSES[:pending]
  end
  
  def processing?
    status == STATUSES[:processing]
  end
  
  def completed?
    status == STATUSES[:completed]
  end
  
  def failed?
    status == STATUSES[:failed]
  end
  
  def duration
    return nil unless started_at
    (completed_at || Time.current) - started_at
  end
  
  def duration_in_minutes
    duration ? (duration / 60).round(2) : nil
  end
  
  def success_rate
    return 0 if processed_items.zero?
    ((processed_items - failed_items).to_f / processed_items * 100).round(2)
  end
  
  def estimated_completion_time
    return nil unless processing? && avg_processing_time && processed_items > 0
    
    remaining_items = total_items - processed_items
    remaining_time = (remaining_items * avg_processing_time) / 1000 / 60  # minutes
    
    Time.current + remaining_time.minutes
  end
  
  # 소스 객체 가져오기
  def source_object
    case source_type
    when SOURCE_TYPES[:collection_task]
      DataPipeline::CollectionTask.find_by(id: source_id)
    when SOURCE_TYPES[:pipedata_import]
      # PipedataImport 모델이 있다면
      nil
    else
      nil
    end
  end
  
  private
  
  def calculate_progress
    return if total_items.zero?
    self.progress = ((processed_items.to_f / total_items) * 100).round
  end
  
  def broadcast_status_update
    # ActionCable로 실시간 업데이트 (향후 구현)
    # VectorDbStatusChannel.broadcast_to(
    #   'admin_dashboard',
    #   { status: self.as_json }
    # )
  end
end