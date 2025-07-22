#!/usr/bin/env ruby
# Verify collection results

puts "🔍 Verifying Collection Results"
puts "=" * 60

# Overall stats
total = KnowledgeBase::QaPair.count
puts "\nTotal QA pairs: #{total}"

# By source
puts "\nBy source:"
KnowledgeBase::QaPair.group(:source).count.each do |source, count|
  puts "  #{source.ljust(15)}: #{count}"
end

# Quality distribution
puts "\nQuality distribution:"
high_quality = KnowledgeBase::QaPair.where("quality_score >= 0.8").count
medium_quality = KnowledgeBase::QaPair.where("quality_score >= 0.6 AND quality_score < 0.8").count
low_quality = KnowledgeBase::QaPair.where("quality_score < 0.6").count

puts "  High (≥0.8):     #{high_quality}"
puts "  Medium (0.6-0.8): #{medium_quality}"
puts "  Low (<0.6):       #{low_quality}"

# Image processing
puts "\nImage processing:"
with_images = KnowledgeBase::QaPair.where("answer LIKE ?", "%[이미지 설명]%")
puts "  With processed images: #{with_images.count}"

# Show examples
if with_images.any?
  puts "\n  Examples of processed images:"
  with_images.limit(3).each_with_index do |qa, idx|
    puts "\n  #{idx + 1}. [#{qa.source}] #{qa.question[0..60]}..."
    
    # Extract image description
    if qa.answer.match(/\[이미지 설명\]\n(.+?)(\n\n|$)/m)
      desc = $1
      puts "     Image desc: #{desc[0..100]}..."
    end
  end
end

# Check metadata
puts "\n\nMetadata analysis:"
with_tags = KnowledgeBase::QaPair.where("metadata->>'tags' IS NOT NULL AND metadata->>'tags' != '[]'").count
with_links = KnowledgeBase::QaPair.where("metadata->>'original_link' IS NOT NULL").count
with_image_meta = KnowledgeBase::QaPair.where("(metadata->>'has_images')::boolean = true").count

puts "  With tags: #{with_tags}"
puts "  With original links: #{with_links}"
puts "  With image metadata: #{with_image_meta}"

# Recent items
puts "\n\nMost recent items:"
KnowledgeBase::QaPair.order(created_at: :desc).limit(5).each_with_index do |qa, idx|
  puts "\n  #{idx + 1}. [#{qa.source}] #{qa.question[0..60]}..."
  puts "     Quality: #{qa.quality_score}, Has images: #{qa.answer.include?('[이미지 설명]')}"
end

puts "\n✅ Verification complete!"