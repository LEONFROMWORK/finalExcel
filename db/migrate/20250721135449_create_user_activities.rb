class CreateUserActivities < ActiveRecord::Migration[8.0]
  def change
    create_table :user_activities do |t|
      t.references :user, null: true, foreign_key: true  # null 허용 (익명 사용자)
      t.string :action, null: false
      t.jsonb :details, default: {}
      t.string :ip_address
      t.string :user_agent
      t.string :session_id
      t.jsonb :location, default: {}  # { country, region, city, timezone }
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.decimal :credits_used, precision: 10, scale: 4, default: 0.0
      t.boolean :success, default: false
      t.string :referrer  # 유입 경로
      t.string :device_type  # mobile, tablet, desktop
      t.float :response_time  # 응답 시간 (ms)

      t.timestamps
    end
    
    # 인덱스 추가
    add_index :user_activities, :action
    add_index :user_activities, :started_at
    add_index :user_activities, :session_id
    add_index :user_activities, [:user_id, :started_at]
    add_index :user_activities, [:action, :success]
    add_index :user_activities, :created_at
  end
end
