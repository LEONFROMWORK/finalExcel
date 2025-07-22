# frozen_string_literal: true

# 파일 업로드 서비스
class FileUploadService
  MAX_FILE_SIZE = 5.megabytes
  ALLOWED_IMAGE_TYPES = %w[image/jpeg image/jpg image/png image/gif image/webp].freeze

  attr_reader :user, :errors

  def initialize(user)
    @user = user
    @errors = []
  end

  # 아바타 업로드
  def upload_avatar(file)
    return { success: false, error: "파일이 없습니다" } unless file.present?

    # 파일 검증
    unless validate_image_file(file)
      return { success: false, errors: @errors }
    end

    begin
      # 기존 아바타 삭제
      user.avatar.purge if user.avatar.attached?

      # 새 아바타 첨부
      user.avatar.attach(file)

      # 썸네일 생성 (백그라운드)
      ProcessImageVariantsJob.perform_later(user)

      {
        success: true,
        avatar_url: avatar_url(user),
        message: "아바타가 업로드되었습니다"
      }
    rescue => e
      Rails.logger.error "Avatar upload failed: #{e.message}"
      { success: false, error: "업로드 중 오류가 발생했습니다" }
    end
  end

  # 아바타 삭제
  def delete_avatar
    return { success: false, error: "아바타가 없습니다" } unless user.avatar.attached?

    user.avatar.purge

    {
      success: true,
      message: "아바타가 삭제되었습니다",
      default_avatar: default_avatar_url
    }
  end

  # Excel 파일 업로드 (기존 ExcelFile 모델과 연동)
  def upload_excel_file(file, options = {})
    return { success: false, error: "파일이 없습니다" } unless file.present?

    unless validate_excel_file(file)
      return { success: false, errors: @errors }
    end

    begin
      excel_file = user.excel_files.build(
        original_filename: file.original_filename,
        file_size: file.size,
        content_type: file.content_type,
        description: options[:description]
      )

      excel_file.file.attach(file)

      if excel_file.save
        # 분석 작업 예약
        AnalyzeExcelFileJob.perform_later(excel_file) if options[:analyze]

        {
          success: true,
          file_id: excel_file.id,
          message: "Excel 파일이 업로드되었습니다"
        }
      else
        { success: false, errors: excel_file.errors.full_messages }
      end
    rescue => e
      Rails.logger.error "Excel upload failed: #{e.message}"
      { success: false, error: "업로드 중 오류가 발생했습니다" }
    end
  end

  private

  def validate_image_file(file)
    # 파일 크기 검증
    if file.size > MAX_FILE_SIZE
      @errors << "파일 크기는 #{MAX_FILE_SIZE / 1.megabyte}MB 이하여야 합니다"
      return false
    end

    # 파일 타입 검증
    unless ALLOWED_IMAGE_TYPES.include?(file.content_type)
      @errors << "지원하지 않는 파일 형식입니다. JPG, PNG, GIF, WebP만 가능합니다"
      return false
    end

    # 이미지 내용 검증 (ImageMagick 사용)
    begin
      image = MiniMagick::Image.new(file.tempfile.path)

      # 이미지 크기 제한
      if image.width > 4000 || image.height > 4000
        @errors << "이미지 크기는 4000x4000 픽셀 이하여야 합니다"
        return false
      end

      true
    rescue => e
      @errors << "유효한 이미지 파일이 아닙니다"
      false
    end
  end

  def validate_excel_file(file)
    allowed_types = %w[
      application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
      application/vnd.ms-excel
      application/x-excel
      application/excel
    ]

    unless allowed_types.include?(file.content_type)
      @errors << "Excel 파일만 업로드 가능합니다"
      return false
    end

    if file.size > 50.megabytes
      @errors << "파일 크기는 50MB 이하여야 합니다"
      return false
    end

    true
  end

  def avatar_url(user)
    return default_avatar_url unless user.avatar.attached?

    Rails.application.routes.url_helpers.rails_blob_url(user.avatar)
  end

  def default_avatar_url
    "https://ui-avatars.com/api/?name=#{CGI.escape(user.email)}&background=3B82F6&color=fff&size=300"
  end
end
