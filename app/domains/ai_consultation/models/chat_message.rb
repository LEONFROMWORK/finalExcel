# frozen_string_literal: true

module AiConsultation
  class ChatMessage < ApplicationRecord
    # Associations
    belongs_to :chat_session
    has_one_attached :image

    # Validations
    validates :content, presence: true, unless: :has_image?
    validates :role, presence: true

    # Enums
    enum :role, {
      user: 0,
      assistant: 1,
      system: 2
    }

    # Scopes
    scope :user_messages, -> { where(role: :user) }
    scope :assistant_messages, -> { where(role: :assistant) }
    scope :recent, -> { order(created_at: :desc) }
    scope :with_attachments, -> { includes(image_attachment: :blob) }

    # Callbacks
    after_create_commit :process_message

    # Instance methods
    def has_image?
      image.attached?
    end

    def image_url
      return nil unless has_image?
      Rails.application.routes.url_helpers.rails_blob_url(image, only_path: true)
    end

    def formatted_content
      return content unless assistant?

      # Format assistant messages with markdown support
      content
    end

    def tokens_used
      metadata["tokens_used"] || 0
    end

    def ai_provider
      metadata["ai_provider"] || "openai"
    end

    def processing_time
      metadata["processing_time"]
    end

    def to_api_format
      {
        id: id,
        role: role,
        content: content,
        has_image: has_image?,
        image_url: image_url,
        created_at: created_at,
        metadata: sanitized_metadata
      }
    end

    private

    def process_message
      return unless user?

      # Queue AI response generation
      Jobs::GenerateAiResponseJob.perform_later(chat_session_id, id)
    end

    def sanitized_metadata
      metadata.except("api_key", "internal_data")
    end
  end
end
