# frozen_string_literal: true

module Api
  module V1
    module DataPipeline
      class CollectionTasksController < Api::V1::BaseController
        before_action :authenticate_user!
        before_action :require_admin!
        before_action :set_collection_task, only: [ :show, :update, :destroy, :start, :stop, :runs, :statistics ]

        def index
          @tasks = collection_repository.find_all_tasks(
            status: params[:status],
            task_type: params[:task_type],
            limit: params[:limit] || 20,
            offset: params[:offset] || 0
          )

          render json: {
            tasks: @tasks.map(&:to_summary),
            total: CollectionTask.count
          }
        end

        def show
          render json: {
            task: @collection_task.to_summary,
            recent_runs: collection_repository.find_runs_for_task(@collection_task.id, limit: 5)
                                             .map(&:to_summary)
          }
        end

        def create
          @collection_task = collection_repository.create_task(
            collection_task_params.merge(created_by: current_user)
          )

          render json: {
            task: @collection_task.to_summary
          }, status: :created
        rescue ActiveRecord::RecordInvalid => e
          render_error(e.record.errors.full_messages, :unprocessable_entity)
        end

        def update
          @collection_task = collection_repository.update_task(
            @collection_task.id,
            collection_task_params
          )

          render json: {
            task: @collection_task.to_summary
          }
        rescue ActiveRecord::RecordInvalid => e
          render_error(e.record.errors.full_messages, :unprocessable_entity)
        end

        def destroy
          @collection_task.disable!
          render json: { message: "Task disabled successfully" }
        end

        def start
          if @collection_task.paused?
            @collection_task.resume!
            message = "Task resumed successfully"
          else
            @collection_task.execute
            message = "Task execution started"
          end

          render json: {
            message: message,
            task: @collection_task.to_summary
          }
        end

        def stop
          @collection_task.pause!

          render json: {
            message: "Task paused successfully",
            task: @collection_task.to_summary
          }
        end

        def runs
          @runs = collection_repository.find_runs_for_task(
            @collection_task.id,
            status: params[:status],
            limit: params[:limit] || 20,
            offset: params[:offset] || 0
          )

          render json: {
            runs: @runs.map(&:to_detailed_report),
            total: @collection_task.collection_runs.count
          }
        end

        def statistics
          stats = collection_repository.task_statistics(@collection_task.id)

          render json: stats
        end

        def global_statistics
          stats = collection_repository.global_statistics(
            params[:user_id] || current_user.id
          )

          render json: stats
        end

        def recent_activity
          activity = collection_repository.recent_activity(params[:limit] || 20)

          render json: {
            activity: activity
          }
        end

        private

        def set_collection_task
          @collection_task = CollectionTask.find(params[:id])
        rescue ActiveRecord::RecordNotFound
          render_error([ "Collection task not found" ], :not_found)
        end

        def collection_task_params
          params.permit(
            :name,
            :description,
            :task_type,
            :schedule,
            source_config: {}
          )
        end

        def collection_repository
          @collection_repository ||= ::DataPipeline::Repositories::CollectionRepository.new
        end

        def require_admin!
          unless current_user.admin?
            render_error([ "Admin access required" ], :forbidden)
          end
        end
      end
    end
  end
end
