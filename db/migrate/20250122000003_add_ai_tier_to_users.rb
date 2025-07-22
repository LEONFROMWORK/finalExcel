class AddAiTierToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :ai_tier, :string, default: 'basic'
    add_column :users, :tier_upgraded_at, :datetime
    add_column :users, :tier_expires_at, :datetime
    add_column :users, :monthly_usage, :jsonb, default: {}

    add_index :users, :ai_tier
    add_index :users, :tier_expires_at

    # 기존 사용자들의 tier는 기본값(basic)으로 설정됨
  end
end
