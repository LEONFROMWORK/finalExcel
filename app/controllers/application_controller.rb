class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # CSRF protection for API
  protect_from_forgery with: :null_session, if: -> { request.format.json? }

  # Serve Vue.js app
  def index
    render file: Rails.public_path.join("index.html"), layout: false
  end

  protected

  # Override Devise's after sign in path
  def after_sign_in_path_for(resource)
    if resource.admin?
      "/admin"
    else
      "/dashboard"
    end
  end
end
