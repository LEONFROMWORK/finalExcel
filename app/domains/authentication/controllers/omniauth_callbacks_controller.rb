# frozen_string_literal: true

module Authentication
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    def google_oauth2
      result = Services::OauthService.call(request.env["omniauth.auth"])

      result.on_success do |user|
        sign_in_and_redirect(user)
      end.on_failure do |errors, _code|
        session["devise.google_data"] = request.env["omniauth.auth"].except("extra")
        redirect_to new_user_registration_url, alert: errors.join(", ")
      end
    end

    def failure
      redirect_to root_path, alert: "Authentication failed."
    end

    private

    def sign_in_and_redirect(user)
      sign_in(user)
      redirect_to after_sign_in_path_for(user)
    end

    def after_sign_in_path_for(resource)
      stored_location_for(resource) || dashboard_path
    end
  end
end
