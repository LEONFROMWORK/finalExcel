class CreateReferralRewards < ActiveRecord::Migration[8.0]
  def change
    create_table :referral_rewards do |t|
      t.integer :referrer_id, null: false
      t.integer :referred_id, null: false
      t.references :referral_code, null: false, foreign_key: true
      t.string :reward_type, null: false  # signup, purchase, milestone
      t.decimal :credits_amount, precision: 10, scale: 2, default: 0.0
      t.string :status, null: false, default: 'pending'  # pending, approved, paid, cancelled
      t.datetime :rewarded_at
      t.jsonb :metadata, default: {}  # 추가 정보 (purchase_amount, milestone_type 등)
      t.string :transaction_id  # 구매 관련 추적

      t.timestamps
    end
    
    # 외래키 추가
    add_foreign_key :referral_rewards, :users, column: :referrer_id
    add_foreign_key :referral_rewards, :users, column: :referred_id
    
    # 인덱스 추가
    add_index :referral_rewards, :referrer_id
    add_index :referral_rewards, :referred_id
    add_index :referral_rewards, :status
    add_index :referral_rewards, [:referrer_id, :status]
    add_index :referral_rewards, [:referred_id, :referral_code_id], unique: true
  end
end
