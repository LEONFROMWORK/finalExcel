module ExcelAnalysis
  class ExcelFile < ApplicationRecord
    belongs_to :user
    has_many :analysis_results, dependent: :destroy
    has_many :chat_sessions, class_name: 'AiConsultation::ChatSession', dependent: :nullify
    
    has_one_attached :original_file
    has_one_attached :processed_file
    has_many_attached :additional_files # For screenshots, etc.

    enum status: {
      pending: 0,
      analyzing: 1,
      completed: 2,
      failed: 3,
      processing: 4
    }

    validates :name, presence: true
    validates :original_file, presence: true

    # Analysis metadata stored in jsonb
    store_accessor :metadata, :sheet_count, :error_count, :formula_count, 
                   :has_vba, :vba_modules, :data_issues, :formula_errors,
                   :enhancement_suggestions, :file_structure

    before_save :extract_file_info, if: :original_file_changed?

    scope :recent, -> { order(created_at: :desc) }
    scope :with_errors, -> { where('error_count > 0') }
    scope :with_vba, -> { where(has_vba: true) }

    def analyze!
      AnalyzeExcelJob.perform_later(self)
    end

    def process_modifications!(modifications)
      ProcessExcelModificationsJob.perform_later(self, modifications)
    end

    def size
      original_file.attached? ? original_file.byte_size : 0
    end

    def human_size
      ActiveSupport::NumberHelper.number_to_human_size(size)
    end

    def has_errors?
      error_count.to_i > 0
    end

    def analysis_complete?
      completed? && analysis_results.any?
    end

    def latest_analysis
      analysis_results.order(created_at: :desc).first
    end

    private

    def extract_file_info
      return unless original_file.attached?
      
      self.name = original_file.filename.to_s if name.blank?
      self.content_type = original_file.content_type
    end

    def original_file_changed?
      original_file.attached? && !persisted?
    end
  end
end