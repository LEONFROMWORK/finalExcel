# frozen_string_literal: true

module Api
  module V1
    module DataPipeline
      class CollectionRunsController < Api::V1::ApiController
        # FREE TEST PERIOD - Authentication disabled
        # before_action :authenticate_user!
        # before_action :require_admin!
        before_action :set_collection_run, only: [ :show, :cancel ]

        def show
          render json: {
            run: @collection_run.to_detailed_report,
            task: @collection_run.collection_task.to_summary
          }
        end

        def cancel
          if @collection_run.cancel!
            render json: {
              message: "Run cancelled successfully",
              run: @collection_run.to_summary
            }
          else
            render_error([ "Cannot cancel run in current state" ], :unprocessable_entity)
          end
        end

        private

        def set_collection_run
          @collection_run = CollectionRun.find(params[:id])
        rescue ActiveRecord::RecordNotFound
          render_error([ "Collection run not found" ], :not_found)
        end

        # require_admin! is already defined in ApiController
      end
    end
  end
end
