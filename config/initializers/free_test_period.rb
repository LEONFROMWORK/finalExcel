# frozen_string_literal: true

# Free Test Period Configuration
# This file controls features during the 3-month free test period

Rails.application.config.free_test_period = {
  enabled: true,
  start_date: Date.new(2025, 7, 22),
  end_date: Date.new(2025, 10, 22),
  
  # Disabled features
  features: {
    authentication: false,
    registration: false,
    payment: false,
    admin_panel: true,  # Admin panel accessible without login
    user_accounts: false,
    credits_system: false,
    notifications: false
  },
  
  # Public features (no login required)
  public_features: {
    excel_analysis: true,
    knowledge_base_search: true,
    ai_consultation: true,
    vba_helper: true,
    data_collection: true
  },
  
  # Test user for API requests (no actual authentication)
  test_user: {
    id: 1,
    email: 'test@excelunified.com',
    name: 'Test User',
    credits: 999999
  }
}

# Disable Devise authentication requirement
if Rails.application.config.free_test_period[:enabled]
  Rails.logger.info "🆓 Free Test Period Mode Enabled - Authentication Disabled"
end