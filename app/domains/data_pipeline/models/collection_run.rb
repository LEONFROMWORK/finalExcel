# frozen_string_literal: true

module DataPipeline
  class CollectionRun < ApplicationRecord
    # Associations
    belongs_to :collection_task

    # Validations
    validates :status, presence: true

    # Enums
    enum :status, {
      pending: 0,
      running: 1,
      completed: 2,
      failed: 3,
      cancelled: 4
    }

    # Scopes
    scope :recent, -> { order(created_at: :desc) }
    scope :successful, -> { where(status: :completed) }
    scope :failed_runs, -> { where(status: :failed) }
    scope :with_errors, -> { where.not(error_message: nil) }

    # Callbacks
    before_save :calculate_duration

    # Instance methods
    def mark_as_running!
      update!(
        status: :running,
        started_at: Time.current
      )
    end

    def mark_as_completed!(stats = {})
      update!(
        status: :completed,
        completed_at: Time.current,
        items_collected: stats[:items_collected] || 0,
        items_processed: stats[:items_processed] || 0,
        result_summary: stats
      )
    end

    def mark_as_failed!(error_message, error_details = nil)
      update!(
        status: :failed,
        completed_at: Time.current,
        error_message: error_message,
        error_details: error_details
      )
    end

    def cancel!
      return false unless can_cancel?

      update!(
        status: :cancelled,
        completed_at: Time.current,
        error_message: "Cancelled by user"
      )
    end

    def can_cancel?
      pending? || running?
    end

    def duration_in_seconds
      return nil unless started_at && completed_at

      (completed_at - started_at).to_i
    end

    def formatted_duration
      return "N/A" unless duration

      hours = duration / 3600
      minutes = (duration % 3600) / 60
      seconds = duration % 60

      if hours > 0
        "#{hours}h #{minutes}m #{seconds}s"
      elsif minutes > 0
        "#{minutes}m #{seconds}s"
      else
        "#{seconds}s"
      end
    end

    def processing_rate
      return 0 unless completed? && duration && duration > 0 && items_processed

      (items_processed.to_f / duration).round(2)
    end

    def success?
      completed?
    end

    def to_summary
      {
        id: id,
        status: status,
        started_at: started_at,
        completed_at: completed_at,
        duration: formatted_duration,
        items_collected: items_collected,
        items_processed: items_processed,
        error_message: error_message
      }
    end

    def to_detailed_report
      {
        id: id,
        collection_task_id: collection_task_id,
        status: status,
        started_at: started_at,
        completed_at: completed_at,
        duration: duration,
        formatted_duration: formatted_duration,
        items_collected: items_collected,
        items_processed: items_processed,
        processing_rate: processing_rate,
        result_summary: result_summary,
        error_message: error_message,
        error_details: error_details,
        created_at: created_at,
        updated_at: updated_at
      }
    end

    private

    def calculate_duration
      if started_at && completed_at
        self.duration = (completed_at - started_at).to_i
      end
    end
  end
end
