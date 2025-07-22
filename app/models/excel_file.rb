# frozen_string_literal: true

# Excel 파일 모델
class ExcelFile < ApplicationRecord
  belongs_to :user
  has_many :analysis_results, dependent: :destroy

  # Active Storage
  has_one_attached :file

  # 검증
  validates :original_filename, presence: true
  validates :file_size, presence: true, numericality: { greater_than: 0 }

  # 스코프
  scope :recent, -> { order(created_at: :desc) }
  scope :analyzed, -> { joins(:analysis_results).distinct }
  scope :pending_analysis, -> { left_joins(:analysis_results).where(analysis_results: { id: nil }) }

  # 파일 타입 확인
  def excel?
    %w[
      application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
      application/vnd.ms-excel
      application/x-excel
      application/excel
    ].include?(content_type)
  end

  # 분석 상태
  def analyzed?
    analysis_results.exists?
  end

  def analysis_status
    return "not_started" unless analyzed?

    latest_result = analysis_results.order(created_at: :desc).first
    latest_result.status || "completed"
  end

  # 파일 URL
  def download_url
    return nil unless file.attached?

    Rails.application.routes.url_helpers.rails_blob_url(file)
  end

  # 파일 크기 (human readable)
  def human_file_size
    return "0 B" unless file_size

    units = [ "B", "KB", "MB", "GB" ]
    size = file_size.to_f
    i = 0

    while size >= 1024 && i < units.length - 1
      size /= 1024.0
      i += 1
    end

    format("%.2f %s", size, units[i])
  end
end
