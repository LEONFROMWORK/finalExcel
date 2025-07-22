class AddReferralFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    # 추천인 관련 필드 추가
    add_column :users, :referral_code_used, :string
    add_column :users, :referrer_id, :integer
    add_column :users, :referred_at, :datetime

    # 마케팅 동의
    add_column :users, :marketing_agreed, :boolean, default: false

    # 구독 관련 필드
    add_column :users, :subscription_plan, :string, default: 'free'
    add_column :users, :subscription_status, :string, default: 'active'
    add_column :users, :next_billing_date, :datetime

    # 알림 설정
    add_column :users, :notification_email, :boolean, default: true
    add_column :users, :notification_sms, :boolean, default: false

    # 기타 프로필 필드
    add_column :users, :phone, :string
    add_column :users, :company, :string
    add_column :users, :bio, :text
    add_column :users, :language, :string, default: 'ko'
    add_column :users, :timezone, :string, default: 'Asia/Seoul'

    # 2FA
    add_column :users, :two_factor_enabled, :boolean, default: false
    add_column :users, :two_factor_secret, :string

    # 소프트 삭제
    add_column :users, :deleted_at, :datetime

    # 인덱스 추가
    add_index :users, :referrer_id
    add_index :users, :referral_code_used
    add_index :users, :deleted_at

    # 외래키 추가
    add_foreign_key :users, :users, column: :referrer_id
  end
end
