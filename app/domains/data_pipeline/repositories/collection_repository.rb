# frozen_string_literal: true

module DataPipeline
  module Repositories
    class CollectionRepository < ::Shared::BaseClasses::ApplicationRepository
      def find_all_tasks(options = {})
        query = CollectionTask.all

        # Apply filters
        query = query.where(status: options[:status]) if options[:status].present?
        query = query.where(task_type: options[:task_type]) if options[:task_type].present?
        query = query.where(created_by_id: options[:user_id]) if options[:user_id].present?

        # Apply ordering - Secure implementation with whitelisting
        query = apply_secure_ordering(query, options[:order_by], options[:order_dir])

        # Apply pagination
        limit = options[:limit] || 20
        offset = options[:offset] || 0
        query.limit(limit).offset(offset)
      end

      def find_task_with_runs(task_id, run_limit = 10)
        CollectionTask.includes(:collection_runs)
                      .where(id: task_id)
                      .first
      end

      def find_user_tasks(user_id, options = {})
        options[:user_id] = user_id
        find_all_tasks(options)
      end

      def create_task(attributes)
        CollectionTask.create!(attributes)
      end

      def update_task(task_id, attributes)
        task = CollectionTask.find(task_id)
        task.update!(attributes)
        task
      end

      def find_runs_for_task(task_id, options = {})
        query = CollectionRun.where(collection_task_id: task_id)

        # Apply filters
        query = query.where(status: options[:status]) if options[:status].present?

        # Apply ordering
        query = query.order(created_at: :desc)

        # Apply pagination
        limit = options[:limit] || 20
        offset = options[:offset] || 0
        query.limit(limit).offset(offset)
      end

      def find_run_details(run_id)
        CollectionRun.includes(:collection_task).find(run_id)
      end

      def task_statistics(task_id)
        task = CollectionTask.find(task_id)
        runs = task.collection_runs

        {
          total_runs: runs.count,
          successful_runs: runs.successful.count,
          failed_runs: runs.failed_runs.count,
          average_duration: task.average_duration,
          success_rate: task.success_rate,
          last_run: task.last_run&.to_summary,
          total_items_collected: runs.sum(:items_collected),
          total_items_processed: runs.sum(:items_processed)
        }
      end

      def global_statistics(user_id = nil)
        query = CollectionTask.all
        query = query.where(created_by_id: user_id) if user_id

        tasks = query
        total_runs = CollectionRun.joins(:collection_task)

        if user_id
          total_runs = total_runs.where(collection_tasks: { created_by_id: user_id })
        end

        {
          total_tasks: tasks.count,
          active_tasks: tasks.active_tasks.count,
          total_runs: total_runs.count,
          successful_runs: total_runs.successful.count,
          failed_runs: total_runs.failed_runs.count,
          total_items_collected: total_runs.sum(:items_collected),
          total_items_processed: total_runs.sum(:items_processed),
          task_types: tasks.group(:task_type).count,
          schedules: tasks.group(:schedule).count
        }
      end

      def recent_activity(limit = 20)
        CollectionRun.includes(:collection_task)
                     .order(created_at: :desc)
                     .limit(limit)
                     .map do |run|
          {
            run_id: run.id,
            task_name: run.collection_task.name,
            task_id: run.collection_task_id,
            status: run.status,
            started_at: run.started_at,
            completed_at: run.completed_at,
            duration: run.formatted_duration,
            items_collected: run.items_collected
          }
        end
      end

      def cleanup_old_runs(days_to_keep = 30)
        cutoff_date = days_to_keep.days.ago

        CollectionRun.where("created_at < ?", cutoff_date)
                     .where(status: [ :completed, :failed, :cancelled ])
                     .destroy_all
      end

      private

      # Whitelist allowed columns and directions to prevent SQL injection
      ALLOWED_ORDER_COLUMNS = %w[created_at updated_at name status task_type schedule].freeze
      ALLOWED_ORDER_DIRECTIONS = %w[asc desc].freeze

      def apply_secure_ordering(query, order_by, order_dir)
        # Validate and sanitize ordering parameters
        order_column = ALLOWED_ORDER_COLUMNS.include?(order_by) ? order_by : "created_at"
        order_direction = ALLOWED_ORDER_DIRECTIONS.include?(order_dir&.downcase) ? order_dir.downcase : "desc"

        # Use hash syntax for secure ordering
        query.order(order_column => order_direction)
      end
    end
  end
end
