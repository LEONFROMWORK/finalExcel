# frozen_string_literal: true

class CreateChatSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :chat_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title
      t.integer :status, default: 0 # 0: active, 1: archived
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    create_table :chat_messages do |t|
      t.references :chat_session, null: false, foreign_key: true
      t.integer :role, null: false # 0: user, 1: assistant
      t.text :content, null: false
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :chat_sessions, :status
    add_index :chat_sessions, :created_at
    add_index :chat_messages, :created_at
  end
end
