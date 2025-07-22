class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.string :type, null: false
      t.string :title, null: false
      t.text :content
      t.jsonb :data, default: {}
      t.boolean :read, default: false, null: false
      t.datetime :read_at
      t.string :action_url
      t.string :action_text
      t.string :priority, default: 'normal'
      t.datetime :expires_at

      t.timestamps
    end

    # 인덱스 추가
    add_index :notifications, [ :user_id, :read ]
    add_index :notifications, [ :user_id, :created_at ]
    add_index :notifications, :type
    add_index :notifications, :priority
    add_index :notifications, :expires_at
  end
end
