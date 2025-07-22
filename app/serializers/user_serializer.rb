# frozen_string_literal: true

# 사용자 직렬화
class UserSerializer
  include Rails.application.routes.url_helpers
  
  attr_reader :user
  
  def initialize(user)
    @user = user
  end
  
  def as_json(_options = {})
    {
      id: user.id,
      email: user.email,
      name: user.name,
      credits: user.credits,
      avatar: avatar_url,
      created_at: user.created_at,
      updated_at: user.updated_at,
      subscription_plan: user.subscription_plan || 'free',
      subscription_status: user.subscription_status || 'active',
      verified: user.respond_to?(:verified_at) ? user.verified_at.present? : false,
      referral_code: user.primary_referral_code&.code,
      settings: {
        notification_email: user.notification_email != false,
        notification_sms: user.notification_sms == true,
        language: user.language || 'ko',
        timezone: user.timezone || 'Asia/Seoul',
        marketing_agreed: user.marketing_agreed == true
      }
    }
  end
  
  private
  
  def avatar_url
    return rails_blob_url(user.avatar) if user.avatar.attached?
    
    default_avatar_url
  end
  
  def default_avatar_url
    name = user.name.presence || user.email
    "https://ui-avatars.com/api/?name=#{CGI.escape(name)}&background=3B82F6&color=fff&size=300"
  end
end