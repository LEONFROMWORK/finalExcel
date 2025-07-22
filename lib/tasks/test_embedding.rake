# frozen_string_literal: true

namespace :embeddings do
  desc "Test embedding service with OpenAI API"
  task test_service: :environment do
    puts "Testing embedding service..."

    # Check if OpenAI API key is set
    if ENV["OPENAI_API_KEY"].blank?
      puts "ERROR: OpenAI API key not set!"
      exit 1
    end

    puts "OpenAI API key found: #{ENV['OPENAI_API_KEY'][0..20]}..."

    # Test with a sample text
    test_text = "How to create pivot tables in Excel"

    begin
      # Test EmbeddingService directly
      embedding_service = EmbeddingService.new
      puts "\nTesting EmbeddingService..."
      embedding = embedding_service.generate_embedding(test_text)

      if embedding.present? && embedding.is_a?(Array)
        puts "✅ Embedding generated successfully!"
        puts "Embedding size: #{embedding.size}"
        puts "First 5 values: #{embedding[0..4].map { |v| v.round(4) }}"
        puts "Service used: OpenAI API (real embeddings)"
      else
        puts "❌ Failed to generate embedding"
      end
    rescue => e
      puts "❌ Error in EmbeddingService: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end

    # Test with a QA pair
    puts "\n\nTesting with QA pair..."
    qa = KnowledgeBase::QaPair.first

    if qa
      puts "Testing with QA ID: #{qa.id}"
      puts "Question: #{qa.question[0..100]}..."

      begin
        # Manually trigger embedding generation
        GenerateEmbeddingJob.perform_now("KnowledgeBase::QaPair", qa.id)

        # Reload to check if embedding was saved
        qa.reload
        if qa.embedding.present? && qa.embedding.size > 0
          puts "✅ Embedding saved to QA pair!"
          puts "Embedding size: #{qa.embedding.size}"
          puts "First 5 values: #{qa.embedding[0..4].map { |v| v.round(4) }}"
        else
          puts "❌ Embedding not saved to QA pair"
        end
      rescue => e
        puts "❌ Error generating embedding for QA pair: #{e.message}"
        puts e.backtrace.first(5).join("\n")
      end
    else
      puts "No QA pairs found in database"
    end

    # Check which service is being used
    puts "\n\nService configuration:"
    puts "OPENAI_API_KEY present: #{ENV['OPENAI_API_KEY'].present?}"
    puts "OPENROUTER_API_KEY present: #{ENV['OPENROUTER_API_KEY'].present?}"

    # Test if we're falling back to AiEmbeddingService
    if ENV["OPENAI_API_KEY"].blank?
      puts "\nWARNING: System would fall back to AiEmbeddingService (fake embeddings)"
    else
      puts "\n✅ System is configured to use real OpenAI embeddings"
    end
  end
end
