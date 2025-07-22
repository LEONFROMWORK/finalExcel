# frozen_string_literal: true

module DataPipeline
  module Jobs
    class SchedulerJob < ApplicationJob
      queue_as :scheduler

      # This job runs periodically to check for due collection tasks
      def perform
        Rails.logger.info "Running data pipeline scheduler at #{Time.current}"

        # Find and execute all due tasks
        due_tasks = CollectionTask.due_for_run

        Rails.logger.info "Found #{due_tasks.count} tasks due for execution"

        due_tasks.find_each do |task|
          begin
            Rails.logger.info "Executing task: #{task.name} (ID: #{task.id})"
            task.execute
          rescue StandardError => e
            Rails.logger.error "Failed to execute task #{task.id}: #{e.message}"
            # Continue with other tasks even if one fails
          end
        end

        Rails.logger.info "Scheduler run completed"
      end
    end
  end
end
