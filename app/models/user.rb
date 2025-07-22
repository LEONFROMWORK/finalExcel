# frozen_string_literal: true

class User < ApplicationRecord
  # Include default devise modules
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [:google_oauth2, :github]
  
  # Associations
  has_many :referral_codes, dependent: :destroy
  has_many :referral_rewards_as_referrer, class_name: 'ReferralReward', foreign_key: 'referrer_id'
  has_many :referral_rewards_as_referred, class_name: 'ReferralReward', foreign_key: 'referred_id'
  has_many :user_activities, dependent: :destroy
  has_many :chat_sessions, dependent: :destroy
  has_many :vba_usage_patterns, dependent: :destroy
  has_many :excel_files, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :credit_transactions, dependent: :destroy
  
  # Active Storage
  has_one_attached :avatar do |attachable|
    attachable.variant :thumb, resize_to_limit: [100, 100]
    attachable.variant :medium, resize_to_limit: [300, 300]
  end
  
  # Self-referential association for referrals
  belongs_to :referrer, class_name: 'User', optional: true
  has_many :referred_users, class_name: 'User', foreign_key: 'referrer_id'
  
  # Validations
  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :credits, numericality: { greater_than_or_equal_to: 0 }
  
  # Attributes
  attr_accessor :referral_code_used
  
  # Scopes
  scope :active, -> { where(deleted_at: nil) }
  scope :deleted, -> { where.not(deleted_at: nil) }
  
  # Callbacks
  after_create :create_default_referral_code
  
  # Instance methods
  def soft_delete!
    update!(deleted_at: Time.current)
  end
  
  def active_for_authentication?
    super && !deleted_at
  end
  
  def inactive_message
    deleted_at ? :deleted : super
  end
  
  # Referral methods
  def has_referral_code?
    referral_codes.active.exists?
  end
  
  def primary_referral_code
    referral_codes.active.first || create_default_referral_code
  end
  
  # Credits methods
  def has_credits?(amount)
    credits >= amount
  end
  
  def deduct_credits!(amount)
    raise 'Insufficient credits' unless has_credits?(amount)
    decrement!(:credits, amount)
  end
  
  def add_credits!(amount)
    increment!(:credits, amount)
  end
  
  # Subscription methods
  def free_plan?
    subscription_plan == 'free'
  end
  
  def pro_plan?
    subscription_plan == 'pro'
  end
  
  def enterprise_plan?
    subscription_plan == 'enterprise'
  end
  
  def subscription_active?
    subscription_status == 'active'
  end
  
  # Notification preferences
  def email_notifications_enabled?
    notification_email != false
  end
  
  def push_notifications_enabled?
    notification_push != false
  end
  
  def recently_notified_by_email?
    notifications.where('created_at > ?', 1.hour.ago).exists?
  end
  
  # Subscription methods
  def self.with_expiring_subscriptions
    where(subscription_status: 'active')
      .where('subscription_expires_at BETWEEN ? AND ?', 3.days.from_now, 7.days.from_now)
  end
  
  def subscription_expires_at
    # 구독 만료일 계산 로직
    next_billing_date
  end
  
  # Activity tracking
  def track_activity(action, details = {})
    UserActivity.track(user: self, action: action, details: details)
  end
  
  private
  
  def create_default_referral_code
    referral_codes.create!(
      referral_type: 'general',
      credits_per_signup: 10,
      credits_per_purchase: 5
    )
  end
end