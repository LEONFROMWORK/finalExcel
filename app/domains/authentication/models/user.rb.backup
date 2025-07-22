# frozen_string_literal: true

module Authentication
  class User < ApplicationRecord
    # Include default devise modules
    devise :database_authenticatable, :registerable,
           :recoverable, :rememberable, :validatable,
           :omniauthable, omniauth_providers: [ :google_oauth2 ]

    # Associations
    has_many :excel_files, class_name: "ExcelAnalysis::ExcelFile", dependent: :destroy
    has_many :chat_sessions, class_name: "AiConsultation::ChatSession", dependent: :destroy
    has_many :chunked_uploads, dependent: :destroy

    # Enums
    enum :role, { user: 0, admin: 1 }

    # Validations
    validates :email, presence: true, uniqueness: true
    validates :name, length: { maximum: 100 }

    # Callbacks
    after_initialize :set_default_role, if: :new_record?

    # Scopes
    scope :admins, -> { where(role: :admin) }
    scope :active, -> { where(active: true) }

    # Class methods
    def self.from_omniauth(auth)
      user = find_by(email: auth.info.email)

      user ||= create!(
        email: auth.info.email,
        provider: auth.provider,
        uid: auth.uid,
        name: auth.info.name,
        password: Devise.friendly_token[0, 20]
      )

      user
    end

    # Instance methods
    def display_name
      name.presence || email.split("@").first
    end

    def admin?
      role == "admin"
    end

    def can_access_admin?
      admin?
    end

    private

    def set_default_role
      self.role ||= :user
    end
  end
end
