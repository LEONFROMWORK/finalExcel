# frozen_string_literal: true

module AiConsultation
  module Services
    class ChatService < ::Shared::BaseClasses::ApplicationService
      attr_reader :chat_session, :message_content, :image, :options

      def initialize(chat_session:, message_content: nil, image: nil, options: {})
        @chat_session = chat_session
        @message_content = message_content
        @image = image
        @options = options
      end

      def call
        validate_input
        return failure(validation_errors, code: :invalid_input) if validation_errors.any?

        # Create user message
        user_message = create_user_message
        return failure([ "Failed to create message" ], code: :creation_failed) unless user_message

        # Generate AI response is handled asynchronously via job
        success(
          {
            message: user_message,
            session: chat_session.summary
          },
          message: "Message sent successfully"
        )
      rescue StandardError => e
        Rails.logger.error "Chat service error: #{e.message}"
        failure([ "Chat service error: #{e.message}" ], code: :service_error)
      end

      private

      def validate_input
        validation_errors << "Chat session is required" unless chat_session
        validation_errors << "Message content or image is required" unless message_content.present? || image.present?

        if image.present?
          validation_errors << "Invalid image format" unless valid_image_format?
          validation_errors << "Image size too large (max 10MB)" if image.size > 10.megabytes
        end
      end

      def validation_errors
        @validation_errors ||= []
      end

      def valid_image_format?
        allowed_types = %w[image/jpeg image/png image/gif image/webp]
        allowed_types.include?(image.content_type)
      end

      def create_user_message
        message = chat_session.messages.build(
          role: :user,
          content: message_content || "Uploaded an image for analysis"
        )

        message.image.attach(image) if image.present?

        message.save ? message : nil
      end
    end
  end
end
