# frozen_string_literal: true

class AssembleChunksJob < ApplicationJob
  queue_as :default

  def perform(chunked_upload_id)
    upload_session = ChunkedUpload.find(chunked_upload_id)
    return if upload_session.complete? || upload_session.failed?

    upload_session.update!(status: "assembling")

    # Assemble file from chunks
    assembled_file_path = assemble_file(upload_session)

    # Create Excel file record
    excel_file = create_excel_file(upload_session, assembled_file_path)

    # Mark upload as completed
    upload_session.mark_as_completed!(excel_file)

    # Clean up chunks
    cleanup_chunks(upload_session)

    # Trigger analysis if file is under 50MB
    if upload_session.file_size < 50.megabytes
      ExcelAnalysis::Services::AnalysisService.new(excel_file: excel_file).call
    end

    Rails.logger.info "Successfully assembled file: #{upload_session.filename}"
  rescue StandardError => e
    Rails.logger.error "Failed to assemble chunks: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    upload_session.mark_as_failed!(e.message)
    cleanup_chunks(upload_session)

    raise # Re-raise for job retry
  end

  private

  def assemble_file(upload_session)
    upload_dir = Rails.root.join("tmp", "uploads")
    FileUtils.mkdir_p(upload_dir)

    filename = "#{SecureRandom.uuid}_#{upload_session.filename}"
    assembled_path = upload_dir.join(filename)

    File.open(assembled_path, "wb") do |output_file|
      # Write chunks in order
      (0...upload_session.total_chunks).each do |chunk_number|
        chunk_path = chunk_file_path(upload_session, chunk_number)

        unless File.exist?(chunk_path)
          raise "Missing chunk #{chunk_number}"
        end

        # Stream chunk to output file
        File.open(chunk_path, "rb") do |chunk_file|
          IO.copy_stream(chunk_file, output_file)
        end
      end
    end

    # Verify file size
    actual_size = File.size(assembled_path)
    if actual_size != upload_session.file_size
      raise "File size mismatch: expected #{upload_session.file_size}, got #{actual_size}"
    end

    assembled_path
  end

  def create_excel_file(upload_session, file_path)
    excel_file = upload_session.user.excel_files.create!(
      filename: upload_session.filename,
      file_url: "/tmp/uploads/#{File.basename(file_path)}",
      file_size: upload_session.file_size,
      status: "uploaded",
      metadata: {
        chunked_upload: true,
        chunks: upload_session.total_chunks,
        upload_duration: Time.current - upload_session.created_at
      }
    )

    excel_file
  end

  def chunk_file_path(upload_session, chunk_number)
    Rails.root.join("tmp", "chunks", upload_session.id.to_s, "chunk_#{chunk_number}")
  end

  def cleanup_chunks(upload_session)
    chunk_dir = Rails.root.join("tmp", "chunks", upload_session.id.to_s)
    FileUtils.rm_rf(chunk_dir) if Dir.exist?(chunk_dir)
  rescue StandardError => e
    Rails.logger.error "Failed to cleanup chunks: #{e.message}"
  end
end
