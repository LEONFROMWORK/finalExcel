# frozen_string_literal: true

class ChunkedUpload < ApplicationRecord
  belongs_to :user, class_name: 'Authentication::User'
  belongs_to :excel_file, class_name: 'ExcelAnalysis::ExcelFile', optional: true
  
  # Validations
  validates :filename, presence: true
  validates :file_size, presence: true, numericality: { greater_than: 0 }
  validates :chunk_size, presence: true, numericality: { greater_than: 0 }
  validates :total_chunks, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true, inclusion: { 
    in: %w[initialized uploading assembling completed failed cancelled] 
  }
  
  # Scopes
  scope :active, -> { where(status: %w[initialized uploading assembling]) }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :recent, -> { order(created_at: :desc) }
  scope :stale, -> { where('created_at < ?', 24.hours.ago) }
  
  # Serialize arrays
  serialize :uploaded_chunks, Array
  
  # Callbacks
  before_create :set_expiration
  
  # Instance methods
  def expired?
    expires_at < Time.current
  end
  
  def complete?
    status == 'completed'
  end
  
  def failed?
    status == 'failed'
  end
  
  def progress_percentage
    return 100.0 if complete?
    return 0.0 if uploaded_chunks.empty?
    
    (uploaded_chunks.size.to_f / total_chunks * 100).round(2)
  end
  
  def missing_chunks
    return [] if complete?
    
    expected_chunks = (0...total_chunks).to_a
    expected_chunks - uploaded_chunks
  end
  
  def mark_as_completed!(excel_file)
    update!(
      status: 'completed',
      excel_file: excel_file,
      completed_at: Time.current
    )
  end
  
  def mark_as_failed!(error_message)
    update!(
      status: 'failed',
      error_message: error_message,
      failed_at: Time.current
    )
  end
  
  private
  
  def set_expiration
    self.expires_at ||= 24.hours.from_now
  end
end