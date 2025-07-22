# frozen_string_literal: true

class GenerateEmbeddingJob < ApplicationJob
  queue_as :default
  
  def perform(model_class, record_id, source_type = nil, source_id = nil)
    record = model_class.constantize.find_by(id: record_id)
    return unless record
    
    embedding_service = EmbeddingService.new
    
    # Generate embedding based on model type
    text = case model_class
           when 'KnowledgeBase::QaPair'
             "#{record.question} #{record.answer}"
           when 'ExcelAnalysis::ExcelFile'
             record.analysis_result.to_s
           else
             record.try(:content) || record.to_s
           end
    
    embedding = embedding_service.generate_embedding(text)
    
    if embedding
      # Update the record with the embedding
      record.update_column(:embedding, embedding)
      Rails.logger.info "Generated embedding for #{model_class}##{record_id}"
      
      # Update VectorDbStatus if tracking is enabled
      if source_type && source_id
        VectorDbStatus.update_progress(
          source_type: source_type,
          source_id: source_id,
          processed: 1,
          embeddings: 1
        )
      end
    else
      Rails.logger.error "Failed to generate embedding for #{model_class}##{record_id}"
      
      # Update VectorDbStatus for failure
      if source_type && source_id
        VectorDbStatus.update_progress(
          source_type: source_type,
          source_id: source_id,
          failed: 1
        )
      end
    end
  rescue StandardError => e
    Rails.logger.error "Embedding job failed: #{e.message}"
    
    # Record error in VectorDbStatus
    if source_type && source_id
      VectorDbStatus.add_error(
        source_type: source_type,
        source_id: source_id,
        error_message: e.message
      )
      VectorDbStatus.update_progress(
        source_type: source_type,
        source_id: source_id,
        failed: 1
      )
    end
    
    raise # Re-raise to trigger retry
  end
end