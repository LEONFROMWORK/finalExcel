# frozen_string_literal: true

module Api
  module V1
    module AiConsultation
      class ChatSessionsController < Api::V1::ApiController
        # FREE TEST PERIOD - Authentication disabled
        # before_action :authenticate_user!
        before_action :set_chat_session, only: [ :show, :update, :destroy, :messages, :export ]

        def index
          @sessions = chat_repository.find_active_sessions_for_user(
            current_user.id,
            limit: params[:limit] || 20,
            offset: params[:offset] || 0
          )

          render json: {
            sessions: @sessions.map(&:summary),
            total: chat_repository.user_session_count(current_user.id)
          }
        end

        def show
          render json: {
            session: @chat_session.summary,
            messages: format_messages(@chat_session.messages.recent.limit(50))
          }
        end

        def create
          @chat_session = chat_repository.create_session_for_user(
            current_user,
            title: params[:title]
          )

          render json: {
            session: @chat_session.summary,
            messages: format_messages(@chat_session.messages)
          }, status: :created
        rescue ActiveRecord::RecordInvalid => e
          render_error(e.record.errors.full_messages, :unprocessable_entity)
        end

        def update
          if @chat_session.update(chat_session_params)
            render json: { session: @chat_session.summary }
          else
            render_error(@chat_session.errors.full_messages, :unprocessable_entity)
          end
        end

        def destroy
          @chat_session.update!(status: :deleted)
          render json: { message: "Session deleted successfully" }
        end

        def messages
          messages = chat_repository.recent_messages_for_session(
            @chat_session.id,
            params[:limit] || 50
          )

          render json: {
            messages: format_messages(messages),
            has_more: messages.size == (params[:limit] || 50).to_i
          }
        end

        def export
          format = params[:format] || "json"
          format = format.to_sym

          export_data = chat_repository.export_session_history(@chat_session.id, format)

          case format
          when :json
            render json: export_data
          when :markdown
            send_data export_data,
                      filename: "chat_session_#{@chat_session.id}_#{Time.current.to_i}.md",
                      type: "text/markdown"
          end
        rescue ArgumentError => e
          render_error([ e.message ], :bad_request)
        end

        def statistics
          stats = {
            total_sessions: chat_repository.user_session_count(current_user.id),
            total_messages: chat_repository.user_message_count(current_user.id),
            popular_topics: chat_repository.popular_topics_for_user(current_user.id)
          }

          render json: stats
        end

        def search
          unless params[:query].present?
            return render_error([ "Query parameter is required" ], :bad_request)
          end

          messages = chat_repository.search_user_messages(
            current_user.id,
            params[:query],
            limit: params[:limit] || 20
          )

          render json: {
            results: messages.map { |msg| format_search_result(msg) },
            query: params[:query],
            total: messages.size
          }
        end

        private

        def set_chat_session
          @chat_session = chat_repository.find_user_session(current_user.id, params[:id])

          unless @chat_session
            render_error([ "Chat session not found" ], :not_found)
          end
        end

        def chat_session_params
          params.permit(:title)
        end

        def chat_repository
          @chat_repository ||= ::AiConsultation::Repositories::ChatRepository.new
        end

        def format_messages(messages)
          messages.map(&:to_api_format)
        end

        def format_search_result(message)
          {
            id: message.id,
            content: message.content,
            role: message.role,
            session_id: message.chat_session_id,
            session_title: message.chat_session.display_title,
            created_at: message.created_at
          }
        end
      end
    end
  end
end
