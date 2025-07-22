class CreateReferralCodes < ActiveRecord::Migration[8.0]
  def change
    create_table :referral_codes do |t|
      t.references :user, null: false, foreign_key: true
      t.string :code, null: false
      t.integer :usage_count, default: 0
      t.integer :max_uses, default: nil  # nil = 무제한
      t.decimal :credits_per_signup, precision: 10, scale: 2, default: 10.0
      t.decimal :credits_per_purchase, precision: 10, scale: 2, default: 5.0
      t.datetime :expires_at
      t.boolean :is_active, default: true
      t.string :referral_type, default: 'general'  # general, special, partner
      t.jsonb :settings, default: {}  # 추가 설정

      t.timestamps
    end

    add_index :referral_codes, :code, unique: true
    add_index :referral_codes, :is_active
    add_index :referral_codes, :expires_at
    add_index :referral_codes, [ :user_id, :is_active ]
  end
end
