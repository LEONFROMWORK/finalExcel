# frozen_string_literal: true

module AiConsultation
  module Repositories
    class ChatRepository < ::Shared::BaseClasses::ApplicationRepository
      def find_active_sessions_for_user(user_id, options = {})
        limit = options[:limit] || 20
        offset = options[:offset] || 0

        ChatSession.active_sessions
                   .where(user_id: user_id)
                   .recent
                   .limit(limit)
                   .offset(offset)
                   .includes(:messages)
      end

      def find_session_with_messages(session_id)
        ChatSession.with_messages.find_by(id: session_id)
      end

      def find_user_session(user_id, session_id)
        ChatSession.find_by(user_id: user_id, id: session_id)
      end

      def create_session_for_user(user, attributes = {})
        user.chat_sessions.create!(attributes)
      end

      def archive_old_sessions(days_ago = 30)
        cutoff_date = days_ago.days.ago

        ChatSession.active
                   .where("updated_at < ?", cutoff_date)
                   .update_all(status: :archived)
      end

      def user_session_count(user_id)
        ChatSession.where(user_id: user_id).count
      end

      def user_message_count(user_id)
        ChatMessage.joins(:chat_session)
                   .where(chat_sessions: { user_id: user_id })
                   .count
      end

      def search_user_messages(user_id, query, options = {})
        limit = options[:limit] || 20

        ChatMessage.joins(:chat_session)
                   .where(chat_sessions: { user_id: user_id })
                   .where("chat_messages.content ILIKE ?", "%#{query}%")
                   .order(created_at: :desc)
                   .limit(limit)
                   .includes(:chat_session)
      end

      def recent_messages_for_session(session_id, limit = 50)
        ChatMessage.where(chat_session_id: session_id)
                   .order(created_at: :desc)
                   .limit(limit)
                   .reverse
      end

      def session_statistics(session_id)
        session = ChatSession.find(session_id)
        messages = session.messages

        {
          total_messages: messages.count,
          user_messages: messages.user_messages.count,
          assistant_messages: messages.assistant_messages.count,
          total_tokens: messages.sum { |m| m.tokens_used },
          images_uploaded: messages.joins(:image_attachment).count,
          first_message_at: messages.minimum(:created_at),
          last_message_at: messages.maximum(:created_at),
          average_response_time: calculate_average_response_time(messages)
        }
      end

      def popular_topics_for_user(user_id, limit = 10)
        # This would analyze message content to extract topics
        # For now, return a simple implementation
        sessions = ChatSession.where(user_id: user_id)
                             .order(message_count: :desc)
                             .limit(limit)

        sessions.map do |session|
          {
            title: session.display_title,
            message_count: session.message_count,
            last_activity: session.updated_at
          }
        end
      end

      def export_session_history(session_id, format = :json)
        session = ChatSession.find(session_id)
        messages = session.messages.order(:created_at)

        case format
        when :json
          export_as_json(session, messages)
        when :markdown
          export_as_markdown(session, messages)
        else
          raise ArgumentError, "Unsupported export format: #{format}"
        end
      end

      private

      def calculate_average_response_time(messages)
        response_times = []

        messages.each_cons(2) do |msg1, msg2|
          if msg1.user? && msg2.assistant?
            response_times << (msg2.created_at - msg1.created_at)
          end
        end

        return 0 if response_times.empty?

        response_times.sum / response_times.size
      end

      def export_as_json(session, messages)
        {
          session: {
            id: session.id,
            title: session.display_title,
            created_at: session.created_at,
            updated_at: session.updated_at,
            status: session.status
          },
          messages: messages.map(&:to_api_format),
          metadata: {
            exported_at: Time.current,
            message_count: messages.count,
            total_tokens: messages.sum(&:tokens_used)
          }
        }
      end

      def export_as_markdown(session, messages)
        markdown = <<~MD
          # #{session.display_title}

          Created: #{session.created_at.strftime('%Y-%m-%d %H:%M')}
          Last Updated: #{session.updated_at.strftime('%Y-%m-%d %H:%M')}
          Status: #{session.status}

          ---

        MD

        messages.each do |message|
          role = message.role.capitalize
          timestamp = message.created_at.strftime("%H:%M")

          markdown += "### #{role} (#{timestamp})\n\n"
          markdown += "#{message.content}\n\n"

          if message.has_image?
            markdown += "_[Image attached]_\n\n"
          end
        end

        markdown
      end
    end
  end
end
