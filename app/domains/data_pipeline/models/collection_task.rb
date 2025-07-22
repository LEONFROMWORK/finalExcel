# frozen_string_literal: true

module DataPipeline
  class CollectionTask < ApplicationRecord
    # Associations
    belongs_to :created_by, class_name: "Authentication::User"
    belongs_to :user, class_name: "Authentication::User", optional: true
    has_many :collection_runs, dependent: :destroy

    # Validations
    validates :name, presence: true, length: { maximum: 255 }
    validates :task_type, presence: true
    validates :schedule, presence: true
    validates :source_config, presence: true

    # Enums
    enum :task_type, {
      web_scraping: 0,
      api_fetch: 1,
      file_import: 2,
      database_sync: 3
    }

    enum :status, {
      active: 0,
      paused: 1,
      disabled: 2
    }

    enum :schedule, {
      manual: 0,
      hourly: 1,
      daily: 2,
      weekly: 3,
      monthly: 4
    }

    # Scopes
    scope :active_tasks, -> { where(status: :active) }
    scope :due_for_run, -> { active_tasks.where("next_run_at <= ?", Time.current) }
    scope :recent, -> { order(created_at: :desc) }

    # Callbacks
    before_create :set_next_run_at
    after_update :reschedule_if_needed

    # Class methods
    def self.run_due_tasks
      due_for_run.find_each do |task|
        task.execute
      end
    end

    # Instance methods
    def execute
      return unless can_run?

      run = collection_runs.create!(
        status: :running,
        started_at: Time.current
      )

      # Execute collection service directly (synchronously for now)
      # In production, this would be done via background job
      result = Services::CollectionService.new(
        collection_task: self,
        collection_run: run
      ).call

      # Update next run time
      update_next_run_at!
      
      run
    end

    def can_run?
      active? && (last_run.nil? || last_run.completed? || last_run.failed?)
    end

    def last_run
      collection_runs.order(created_at: :desc).first
    end

    def success_rate
      return 0 if collection_runs.count.zero?

      successful = collection_runs.where(status: :completed).count
      total = collection_runs.count

      ((successful.to_f / total) * 100).round(2)
    end

    def average_duration
      completed_runs = collection_runs.where(status: :completed)
                                    .where.not(duration: nil)

      return 0 if completed_runs.count.zero?

      completed_runs.average(:duration).to_i
    end

    def pause!
      update!(status: :paused)
    end

    def resume!
      update!(status: :active, next_run_at: calculate_next_run_at)
    end

    def disable!
      update!(status: :disabled)
    end

    def source_url
      source_config["url"]
    end

    def api_endpoint
      source_config["endpoint"]
    end

    def processing_options
      {
        parser: source_config["parser"] || "default",
        filters: source_config["filters"] || {},
        transformations: source_config["transformations"] || []
      }
    end

    def to_summary
      {
        id: id,
        name: name,
        task_type: task_type,
        status: status,
        schedule: schedule,
        last_run: last_run&.to_summary,
        next_run_at: next_run_at,
        success_rate: success_rate,
        created_at: created_at
      }
    end

    private

    def set_next_run_at
      self.next_run_at ||= calculate_next_run_at
    end

    def calculate_next_run_at
      case schedule
      when "manual"
        nil
      when "hourly"
        1.hour.from_now
      when "daily"
        1.day.from_now
      when "weekly"
        1.week.from_now
      when "monthly"
        1.month.from_now
      else
        nil
      end
    end

    def update_next_run_at!
      update!(next_run_at: calculate_next_run_at)
    end

    def reschedule_if_needed
      if saved_change_to_schedule? && active?
        update_next_run_at!
      end
    end
  end
end
