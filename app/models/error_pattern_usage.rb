# frozen_string_literal: true

class ErrorPatternUsage < ApplicationRecord
  belongs_to :error_pattern
  belongs_to :user, class_name: 'Authentication::User', optional: true
  
  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :resolved, -> { where(resolved: true) }
  scope :with_feedback, -> { where.not(feedback: nil) }
  scope :positive_feedback, -> { where('feedback >= ?', 4) }
  
  # Validations
  validates :feedback, inclusion: { in: 1..5 }, allow_nil: true
  
  # Callbacks
  after_create :increment_pattern_usage_count
  after_update :update_pattern_effectiveness, if: :saved_change_to_feedback?
  
  private
  
  def increment_pattern_usage_count
    error_pattern.increment!(:usage_count)
  end
  
  def update_pattern_effectiveness
    # 효과성 점수 재계산
    UpdatePatternEffectivenessJob.perform_later(error_pattern)
  end
end