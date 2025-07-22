# frozen_string_literal: true

module Api
  module V1
    module AiConsultation
      class MessagesController < Api::V1::ApiController
        # FREE TEST PERIOD - Authentication disabled
        # before_action :authenticate_user!
        before_action :set_chat_session

        def create
          result = chat_service.call

          result.on_success do |data|
            render json: {
              message: data[:message].to_api_format,
              session: data[:session]
            }, status: :created
          end.on_failure do |errors, code|
            render_error(errors, status_for_code(code))
          end
        end

        private

        def set_chat_session
          @chat_session = chat_repository.find_user_session(
            current_user.id,
            params[:chat_session_id]
          )

          unless @chat_session
            render_error([ "Chat session not found" ], :not_found)
          end
        end

        def chat_service
          ::AiConsultation::Services::ChatService.new(
            chat_session: @chat_session,
            message_content: params[:content],
            image: params[:image]
          )
        end

        def chat_repository
          @chat_repository ||= ::AiConsultation::Repositories::ChatRepository.new
        end

        def status_for_code(code)
          case code
          when :invalid_input then :unprocessable_entity
          when :creation_failed then :unprocessable_entity
          when :service_error then :internal_server_error
          else :bad_request
          end
        end
      end
    end
  end
end
