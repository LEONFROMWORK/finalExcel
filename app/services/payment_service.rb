# frozen_string_literal: true

# 결제 처리 서비스
class PaymentService
  attr_reader :user, :referral_service
  
  def initialize(user)
    @user = user
    @referral_service = ReferralService.new(user)
  end
  
  # 크레딧 구매 처리
  def purchase_credits(package_id, amount, payment_method, options = {})
    ActiveRecord::Base.transaction do
      # 결제 처리 (실제로는 PG사 연동)
      payment_result = process_payment(amount, payment_method, options)
      
      unless payment_result[:success]
        raise PaymentError, payment_result[:error]
      end
      
      # 크레딧 패키지 정보
      package = get_credit_package(package_id)
      total_credits = package[:credits] + (package[:bonus] || 0)
      
      # 크레딧 추가
      user.add_credits!(total_credits)
      
      # 크레딧 거래 내역 생성
      transaction = create_credit_transaction(
        transaction_type: 'purchase',
        amount: total_credits,
        price_paid: amount,
        payment_method: payment_method,
        payment_transaction_id: payment_result[:transaction_id],
        metadata: {
          package_id: package_id,
          bonus_credits: package[:bonus] || 0
        }
      )
      
      # 알림 전송
      NotificationService.new(user).send_credit_notification(transaction)
      
      # 첫 구매인 경우 추천인 보상 처리
      if first_purchase?
        referral_service.process_purchase_reward(user, amount)
      end
      
      # 활동 기록
      UserActivity.track(
        user: user,
        action: 'credit_purchase',
        details: {
          package_id: package_id,
          credits: total_credits,
          amount: amount,
          payment_method: payment_method,
          first_purchase: first_purchase?
        }
      )
      
      {
        success: true,
        credits_added: total_credits,
        new_balance: user.credits,
        transaction_id: payment_result[:transaction_id]
      }
    end
  rescue PaymentError => e
    {
      success: false,
      error: e.message
    }
  rescue => e
    Rails.logger.error "Payment processing failed: #{e.message}"
    {
      success: false,
      error: '결제 처리 중 오류가 발생했습니다'
    }
  end
  
  # 구독 결제 처리
  def process_subscription(plan_id, payment_method)
    ActiveRecord::Base.transaction do
      plan = get_subscription_plan(plan_id)
      
      # 결제 처리
      payment_result = process_payment(plan[:price], payment_method, recurring: true)
      
      unless payment_result[:success]
        raise PaymentError, payment_result[:error]
      end
      
      # 구독 정보 업데이트
      user.update!(
        subscription_plan: plan_id,
        subscription_status: 'active',
        next_billing_date: 1.month.from_now
      )
      
      # 구독 플랜에 따른 크레딧 지급
      if plan[:monthly_credits] > 0
        user.add_credits!(plan[:monthly_credits])
        
        create_credit_transaction(
          transaction_type: 'subscription_credit',
          amount: plan[:monthly_credits],
          price_paid: 0,
          metadata: {
            plan_id: plan_id,
            billing_period: Date.current.strftime('%Y-%m')
          }
        )
      end
      
      # 첫 결제인 경우 추천인 보상
      if first_purchase?
        referral_service.process_purchase_reward(user, plan[:price])
      end
      
      # 활동 기록
      UserActivity.track(
        user: user,
        action: 'subscription_purchase',
        details: {
          plan_id: plan_id,
          price: plan[:price],
          payment_method: payment_method
        }
      )
      
      {
        success: true,
        plan: plan_id,
        next_billing_date: user.next_billing_date
      }
    end
  rescue PaymentError => e
    {
      success: false,
      error: e.message
    }
  end
  
  # 환불 처리
  def process_refund(transaction_id, reason = nil)
    transaction = find_credit_transaction(transaction_id)
    
    unless transaction && transaction.refundable?
      return { success: false, error: '환불할 수 없는 거래입니다' }
    end
    
    ActiveRecord::Base.transaction do
      # PG사 환불 처리
      refund_result = process_payment_refund(transaction.payment_transaction_id)
      
      unless refund_result[:success]
        raise PaymentError, refund_result[:error]
      end
      
      # 크레딧 차감
      credits_to_deduct = transaction.amount
      if user.credits < credits_to_deduct
        # 부족한 경우 있는 만큼만 차감
        credits_to_deduct = user.credits
      end
      
      user.deduct_credits!(credits_to_deduct) if credits_to_deduct > 0
      
      # 환불 기록
      create_credit_transaction(
        transaction_type: 'refund',
        amount: -credits_to_deduct,
        price_paid: -transaction.price_paid,
        related_transaction_id: transaction.id,
        metadata: {
          reason: reason,
          original_transaction_id: transaction_id,
          refund_transaction_id: refund_result[:refund_id]
        }
      )
      
      # 거래 상태 업데이트
      transaction.update!(status: 'refunded', refunded_at: Time.current)
      
      {
        success: true,
        refunded_credits: credits_to_deduct,
        refunded_amount: transaction.price_paid
      }
    end
  rescue PaymentError => e
    {
      success: false,
      error: e.message
    }
  end
  
  private
  
  def first_purchase?
    # 크레딧 거래 내역이 있는지 확인 (가입 보너스 제외)
    !CreditTransaction.where(user: user, transaction_type: ['purchase', 'subscription_purchase']).exists?
  end
  
  def process_payment(amount, payment_method, options = {})
    # 실제 PG사 연동 로직
    # 여기서는 모의 구현
    case payment_method
    when 'card'
      # 카드 결제 처리
      { success: true, transaction_id: "TXN_#{SecureRandom.hex(8)}" }
    when 'kakao'
      # 카카오페이 처리
      { success: true, transaction_id: "KAKAO_#{SecureRandom.hex(8)}" }
    when 'naver'
      # 네이버페이 처리
      { success: true, transaction_id: "NAVER_#{SecureRandom.hex(8)}" }
    when 'toss'
      # 토스 처리
      { success: true, transaction_id: "TOSS_#{SecureRandom.hex(8)}" }
    else
      { success: false, error: '지원하지 않는 결제 방법입니다' }
    end
  end
  
  def process_payment_refund(transaction_id)
    # 실제 PG사 환불 API 호출
    { success: true, refund_id: "REFUND_#{SecureRandom.hex(8)}" }
  end
  
  def get_credit_package(package_id)
    packages = {
      'starter' => { credits: 100, bonus: 0, price: 9900 },
      'popular' => { credits: 500, bonus: 50, price: 39900 },
      'pro' => { credits: 1000, bonus: 150, price: 69900 }
    }
    
    packages[package_id] || { credits: 100, bonus: 0, price: package_id.to_i * 100 }
  end
  
  def get_subscription_plan(plan_id)
    plans = {
      'pro' => { 
        price: 29000,
        monthly_credits: 500,
        features: ['unlimited_ai_chat', 'advanced_analysis', 'priority_support']
      },
      'enterprise' => {
        price: 99000,
        monthly_credits: 2000,
        features: ['all_pro_features', 'dedicated_support', 'custom_ai_model']
      }
    }
    
    plans[plan_id] || raise("Invalid subscription plan: #{plan_id}")
  end
  
  def create_credit_transaction(attributes)
    CreditTransaction.create!(
      attributes.merge(
        user: user,
        balance_after: user.credits,
        status: 'completed'
      )
    )
  end
  
  def find_credit_transaction(transaction_id)
    CreditTransaction.find_by(id: transaction_id, user: user)
  end
  
  class PaymentError < StandardError; end
end