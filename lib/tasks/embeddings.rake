namespace :embeddings do
  desc "Test OpenAI embedding generation"
  task test: :environment do
    service = EmbeddingService.new
    
    test_text = "This is a test text for embedding generation"
    puts "Testing embedding generation for: #{test_text}"
    
    embedding = service.generate_embedding(test_text)
    
    if embedding
      puts "✓ Embedding generated successfully!"
      puts "  Dimensions: #{embedding.size}"
      puts "  First 5 values: #{embedding.first(5).join(', ')}"
    else
      puts "✗ Failed to generate embedding"
      puts "  Make sure OPENAI_API_KEY is set in your environment"
    end
  end
  
  desc "Generate embeddings for all QA pairs"
  task generate_qa_pairs: :environment do
    qa_pairs = KnowledgeBase::QaPair.where(embedding: nil)
    total = qa_pairs.count
    
    puts "Found #{total} QA pairs without embeddings"
    
    qa_pairs.find_each.with_index do |qa, index|
      GenerateEmbeddingJob.perform_later('KnowledgeBase::QaPair', qa.id)
      puts "Queued embedding job for QA pair #{qa.id} (#{index + 1}/#{total})"
    end
    
    puts "All embedding jobs queued!"
  end
  
  desc "Generate embeddings for analyzed Excel files"
  task generate_excel_files: :environment do
    excel_files = ExcelAnalysis::ExcelFile.where(embedding: nil)
                                          .where.not(analysis_result: nil)
    total = excel_files.count
    
    puts "Found #{total} Excel files without embeddings"
    
    excel_files.find_each.with_index do |file, index|
      GenerateEmbeddingJob.perform_later('ExcelAnalysis::ExcelFile', file.id)
      puts "Queued embedding job for Excel file #{file.id} (#{index + 1}/#{total})"
    end
    
    puts "All embedding jobs queued!"
  end
end