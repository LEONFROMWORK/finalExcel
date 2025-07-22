# frozen_string_literal: true

module DataPipeline
  module Jobs
    class CollectionJob < ApplicationJob
      queue_as :data_collection

      def perform(collection_task_id, collection_run_id)
        @collection_task = CollectionTask.find(collection_task_id)
        @collection_run = CollectionRun.find(collection_run_id)

        # Execute the collection
        result = Services::CollectionService.call(
          collection_task: @collection_task,
          collection_run: @collection_run
        )

        if result.success?
          Rails.logger.info "Collection completed: #{result.message}"

          # Notify success (could send email, webhook, etc.)
          notify_completion(result.data)
        else
          Rails.logger.error "Collection failed: #{result.errors.join(', ')}"

          # Notify failure
          notify_failure(result.errors)
        end
      rescue StandardError => e
        Rails.logger.error "Collection job error: #{e.message}"

        @collection_run.mark_as_failed!(
          "Job execution error: #{e.message}",
          { error_class: e.class.name, backtrace: e.backtrace }
        )

        raise # Re-raise to trigger retry if configured
      end

      private

      def notify_completion(data)
        # Send notifications based on task configuration
        notification_config = @collection_task.source_config["notifications"] || {}

        if notification_config["email"].present?
          # Send email notification
          Rails.logger.info "Would send completion email to #{notification_config['email']}"
        end

        if notification_config["webhook"].present?
          # Send webhook
          send_webhook(notification_config["webhook"], {
            event: "collection_completed",
            task_id: @collection_task.id,
            run_id: @collection_run.id,
            items_collected: data[:items_collected],
            items_processed: data[:items_processed]
          })
        end
      end

      def notify_failure(errors)
        notification_config = @collection_task.source_config["notifications"] || {}

        if notification_config["email"].present?
          # Send failure email
          Rails.logger.info "Would send failure email to #{notification_config['email']}"
        end

        if notification_config["webhook"].present?
          # Send webhook
          send_webhook(notification_config["webhook"], {
            event: "collection_failed",
            task_id: @collection_task.id,
            run_id: @collection_run.id,
            errors: errors
          })
        end
      end

      def send_webhook(url, payload)
        # In production, use HTTParty or similar to send webhook
        Rails.logger.info "Would send webhook to #{url} with payload: #{payload.to_json}"
      end
    end
  end
end
