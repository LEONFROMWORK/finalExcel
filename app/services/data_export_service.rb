# frozen_string_literal: true

require 'json'
require 'fileutils'

class DataExportService
  EXPORT_DIR = Rails.root.join('tmp', 'exports')

  def initialize
    FileUtils.mkdir_p(EXPORT_DIR)
  end

  def export_for_rag(qa_pairs)
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    filename = "rag_export_#{timestamp}.json"
    filepath = EXPORT_DIR.join(filename)

    begin
      # Prepare data for RAG system
      data = {
        export_date: Time.current.iso8601,
        total_count: qa_pairs.count,
        qa_pairs: qa_pairs.map { |qa| format_qa_for_rag(qa) }
      }

      # Write to file
      File.write(filepath, JSON.pretty_generate(data))

      # If Python service is available, send directly
      if python_service_available?
        send_to_python_service(data)
      end

      {
        success: true,
        count: qa_pairs.count,
        file_path: filepath.to_s,
        message: "데이터가 성공적으로 내보내졌습니다"
      }
    rescue => e
      Rails.logger.error "Export for RAG failed: #{e.message}"
      {
        success: false,
        error: e.message
      }
    end
  end

  def export_to_json(qa_pairs, include_embeddings: false)
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    filename = "qa_export_#{timestamp}.json"
    filepath = EXPORT_DIR.join(filename)

    begin
      data = {
        export_date: Time.current.iso8601,
        total_count: qa_pairs.count,
        with_embeddings: qa_pairs.where.not(embedding: nil).count,
        sources: qa_pairs.group(:source).count,
        qa_pairs: qa_pairs.map { |qa| format_qa(qa, include_embeddings) }
      }

      File.write(filepath, JSON.pretty_generate(data))

      {
        success: true,
        file_path: filepath.to_s,
        size: File.size(filepath)
      }
    rescue => e
      Rails.logger.error "JSON export failed: #{e.message}"
      {
        success: false,
        error: e.message
      }
    end
  end

  private

  def format_qa_for_rag(qa)
    {
      id: qa.id,
      question: qa.question,
      answer: qa.answer,
      source: qa.source,
      tags: qa.tags,
      quality_score: qa.quality_score,
      metadata: {
        has_images: qa.metadata&.dig('has_images') || false,
        image_count: qa.metadata&.dig('images')&.size || 0,
        created_at: qa.created_at.iso8601,
        approved: qa.is_approved
      },
      embedding: qa.embedding # Always include for RAG
    }
  end

  def format_qa(qa, include_embeddings)
    data = {
      id: qa.id,
      question: qa.question,
      answer: qa.answer,
      source: qa.source,
      tags: qa.tags,
      quality_score: qa.quality_score,
      is_approved: qa.is_approved,
      created_at: qa.created_at.iso8601,
      metadata: qa.metadata
    }

    data[:embedding] = qa.embedding if include_embeddings

    data
  end

  def python_service_available?
    return false unless ENV['PYTHON_SERVICE_URL'].present?

    begin
      uri = URI("#{ENV['PYTHON_SERVICE_URL']}/health")
      response = Net::HTTP.get_response(uri)
      response.code == '200'
    rescue
      false
    end
  end

  def send_to_python_service(data)
    uri = URI("#{ENV['PYTHON_SERVICE_URL']}/api/v1/knowledge_base/import")
    
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = data.to_json

    Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
      response = http.request(request)
      Rails.logger.info "Sent to Python service: #{response.code}"
    end
  rescue => e
    Rails.logger.error "Failed to send to Python service: #{e.message}"
  end
end