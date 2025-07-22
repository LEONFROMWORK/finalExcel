# frozen_string_literal: true

class PatternValidation < ApplicationRecord
  belongs_to :error_pattern
  
  # Scopes
  scope :by_type, ->(type) { where(validation_type: type) }
  scope :passed, -> { where('score >= ?', 0.7) }
  scope :failed, -> { where('score < ?', 0.7) }
  scope :recent, -> { order(created_at: :desc) }
  
  # Validations
  validates :validation_type, presence: true
  validates :score, numericality: { in: 0..1 }
  validates :validated_by, presence: true
  
  # Validation types
  VALIDATION_TYPES = %w[
    syntax
    logic
    feasibility
    hallucination
    human_review
  ].freeze
  
  validates :validation_type, inclusion: { in: VALIDATION_TYPES }
  
  def passed?
    score >= 0.7
  end
  
  def failed?
    !passed?
  end
  
  def critical_issues?
    issues['critical'].present? && issues['critical'].any?
  end
end