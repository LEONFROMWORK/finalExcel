#!/usr/bin/env ruby
# Import collected JSON data into database

# Helper method to calculate quality score
def calculate_quality_score(item)
  score = 0.5 # Base score
  
  # Add points for various quality indicators
  score += 0.1 if item[:answer].length > 100
  score += 0.1 if item[:images].present? && item[:images].any?
  score += 0.1 if item[:tags].present? && item[:tags].any?
  score += 0.1 if item.dig(:metadata, :answer_score).to_i > 0
  score += 0.1 if item[:answer].include?('[이미지 설명]')
  
  [score, 1.0].min
end

puts "📥 Importing collected data to database..."
puts "=" * 60

# Directory where JSON files are saved
export_dir = Rails.root.join('tmp', 'platform_datasets')
date_str = Date.current.strftime('%Y%m%d')

# Import data from each platform
platforms = ['stackoverflow', 'reddit', 'mrexcel', 'oppadu']
total_imported = 0

platforms.each do |platform|
  filename = "#{platform}_dataset_#{date_str}.json"
  filepath = export_dir.join(filename)
  
  if File.exist?(filepath)
    puts "\n📄 Processing #{platform}..."
    
    # Load JSON data
    data = JSON.parse(File.read(filepath), symbolize_names: true)
    items = data[:items] || []
    
    imported = 0
    skipped = 0
    
    items.each do |item|
      begin
        # Check if already exists
        existing = KnowledgeBase::QaPair.find_by(
          question: item[:question],
          source: platform
        )
        
        if existing
          skipped += 1
          next
        end
        
        # Create new QA pair
        qa_pair = KnowledgeBase::QaPair.create!(
          question: item[:question],
          answer: item[:answer],
          source: platform,
          metadata: {
            tags: item[:tags] || [],
            original_link: item[:link],
            has_images: item[:images].present? && item[:images].any?,
            image_count: item[:images]&.size || 0,
            collected_at: item[:collected_at],
            platform_metadata: item[:metadata] || {}
          },
          quality_score: calculate_quality_score(item),
          approved: true # Auto-approve collected data
        )
        
        imported += 1
        
      rescue => e
        puts "  ❌ Error importing item: #{e.message}"
        puts "     Title: #{item[:title]}"
      end
    end
    
    puts "  ✅ Imported: #{imported}, Skipped: #{skipped}"
    total_imported += imported
  else
    puts "\n⚠️  No data file found for #{platform}"
  end
end

puts "\n📊 IMPORT SUMMARY"
puts "=" * 60
puts "Total imported: #{total_imported}"
puts "Database count: #{KnowledgeBase::QaPair.count}"

# Verify image processing
qa_with_images = KnowledgeBase::QaPair.where("answer LIKE ?", "%[이미지 설명]%").count
puts "QA pairs with processed images: #{qa_with_images}"

# Show sample
if KnowledgeBase::QaPair.any?
  sample = KnowledgeBase::QaPair.last
  puts "\nSample QA pair:"
  puts "  Question: #{sample.question[0..80]}..."
  puts "  Source: #{sample.source}"
  puts "  Quality: #{sample.quality_score}"
  puts "  Has images: #{sample.answer.include?('[이미지 설명]')}"
end