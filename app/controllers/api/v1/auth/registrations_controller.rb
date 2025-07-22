# frozen_string_literal: true

module Api
  module V1
    module Auth
      # 회원가입 컨트롤러
      class RegistrationsController < Devise::RegistrationsController
        respond_to :json

        # POST /api/v1/auth/signup
        def create
          build_resource(sign_up_params)

          # 추천인 코드 처리
          if params[:user][:referral_code].present?
            referral_service = ReferralService.new(nil)
            referral_result = referral_service.use_referral_code(
              params[:user][:referral_code],
              resource
            )

            unless referral_result[:success]
              return render json: {
                success: false,
                errors: { referral_code: [ referral_result[:error] ] }
              }, status: :unprocessable_entity
            end

            # 추천인 정보를 임시로 저장
            resource.referral_code_used = params[:user][:referral_code]
            resource.referrer_id = referral_result[:referrer].id
          end

          resource.save

          if resource.persisted?
            # 추천인 코드가 있었다면 보상 처리
            if resource.referral_code_used.present?
              process_referral_reward(resource)
            end

            # 기본 크레딧 지급
            resource.update!(credits: 10) # 기본 가입 크레딧

            # 활동 기록
            UserActivity.track(
              user: resource,
              action: "signup",
              details: {
                referral_code: resource.referral_code_used,
                source: "web"
              }
            )

            if resource.active_for_authentication?
              sign_up(resource_name, resource)
              render json: {
                success: true,
                user: serialize_user(resource),
                message: "회원가입이 완료되었습니다"
              }
            else
              expire_data_after_sign_in!
              render json: {
                success: true,
                message: "이메일 인증이 필요합니다"
              }
            end
          else
            clean_up_passwords resource
            set_minimum_password_length
            render json: {
              success: false,
              errors: resource.errors
            }, status: :unprocessable_entity
          end
        end

        # POST /api/v1/auth/validate-referral
        def validate_referral
          code = params[:code]&.strip

          if code.blank?
            return render json: { valid: false, error: "추천 코드를 입력해주세요" }
          end

          referral_code = ReferralCode.find_by_code(code)

          if referral_code && referral_code.can_be_used?
            render json: {
              valid: true,
              referrer_name: referral_code.user.name || referral_code.user.email.split("@").first,
              signup_credits: referral_code.credits_per_signup
            }
          else
            render json: { valid: false }
          end
        end

        private

        def sign_up_params
          params.require(:user).permit(
            :email, :password, :password_confirmation,
            :name, :marketing_agreed
          )
        end

        def process_referral_reward(user)
          return unless user.referral_code_used.present?

          referral_code = ReferralCode.find_by_code(user.referral_code_used)
          return unless referral_code

          # 추천인 코드 사용 처리
          referral_code.use!(user)

          # 신규 가입자에게 추가 크레딧 지급
          bonus_credits = 10 # 추천으로 가입 시 보너스
          user.increment!(:credits, bonus_credits)

          # 활동 기록
          UserActivity.track(
            user: user,
            action: "referral_bonus_received",
            details: {
              referrer_id: referral_code.user_id,
              bonus_credits: bonus_credits
            }
          )
        end

        def serialize_user(user)
          {
            id: user.id,
            email: user.email,
            name: user.name,
            credits: user.credits,
            created_at: user.created_at
          }
        end
      end
    end
  end
end
