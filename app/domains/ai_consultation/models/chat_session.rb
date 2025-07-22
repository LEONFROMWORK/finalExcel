# frozen_string_literal: true

module AiConsultation
  class ChatSession < ApplicationRecord
    # Associations
    belongs_to :user, class_name: "Authentication::User"
    has_many :messages, -> { order(created_at: :asc) },
             class_name: "ChatMessage",
             dependent: :destroy

    # Validations
    validates :title, length: { maximum: 255 }

    # Enums
    enum status: {
      active: 0,
      archived: 1,
      deleted: 2
    }

    # Scopes
    scope :active_sessions, -> { where(status: :active) }
    scope :recent, -> { order(updated_at: :desc) }
    scope :with_messages, -> { includes(:messages) }

    # Callbacks
    before_create :set_default_title
    after_create :create_welcome_message

    # Class methods
    def self.create_for_user(user, title: nil)
      create!(
        user: user,
        title: title || generate_default_title,
        status: :active
      )
    end

    # Instance methods
    def add_user_message(content)
      messages.create!(
        role: :user,
        content: content
      )
    end

    def add_assistant_message(content, metadata = {})
      messages.create!(
        role: :assistant,
        content: content,
        metadata: metadata
      )
    end

    def last_message
      messages.last
    end

    def message_count
      messages.count
    end

    def archive!
      update!(status: :archived)
    end

    def reactivate!
      update!(status: :active)
    end

    def summary
      {
        id: id,
        title: display_title,
        message_count: message_count,
        last_activity: updated_at,
        status: status
      }
    end

    def display_title
      title.presence || "Chat #{created_at.strftime('%Y-%m-%d %H:%M')}"
    end

    private

    def set_default_title
      self.title ||= self.class.generate_default_title
    end

    def self.generate_default_title
      "Excel 상담 #{Time.current.strftime('%Y-%m-%d %H:%M')}"
    end

    def create_welcome_message
      add_assistant_message(
        "안녕하세요! Excel 관련 질문이나 문제가 있으시면 말씀해주세요. 수식 오류, 데이터 분석, 차트 생성 등 다양한 도움을 드릴 수 있습니다. 스크린샷을 업로드하셔도 됩니다!"
      )
    end
  end
end
