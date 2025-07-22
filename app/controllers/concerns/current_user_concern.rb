module CurrentUserConcern
  extend ActiveSupport::Concern

  included do
    before_action :set_current_user
  end

  private

  def set_current_user
    @current_user = current_authentication_user if user_signed_in?
  end

  def current_user
    @current_user || current_authentication_user
  end
end