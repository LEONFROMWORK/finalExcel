#!/usr/bin/env ruby
# Clear existing data and recollect from all platforms

puts "🧹 Clearing existing collected data..."
puts "=" * 60

# Clear KnowledgeBase::QaPair data
begin
  # Delete all QA pairs
  qa_count = KnowledgeBase::QaPair.count
  KnowledgeBase::QaPair.destroy_all
  puts "✅ Deleted #{qa_count} QA pairs"

  # Clear any cached data
  Rails.cache.clear
  puts "✅ Cleared Rails cache"

rescue => e
  puts "❌ Error clearing data: #{e.message}"
  exit 1
end

puts "\n📊 Starting fresh collection from all platforms (20 items each)..."
puts "=" * 60

# Define platforms
platforms = [ 'stackoverflow', 'reddit', 'mrexcel', 'oppadu' ]
limit = 20
total_success = 0
results_summary = {}

# Collect from each platform
platforms.each do |platform|
  puts "\n🌐 Collecting from #{platform.upcase}..."
  puts "-" * 40

  begin
    collector = PlatformDataCollector.new(platform)
    result = collector.collect_data(limit)

    if result[:success]
      count = result[:results].size
      total_success += count
      results_summary[platform] = {
        success: true,
        count: count,
        has_images: result[:results].any? { |r| r[:images].present? && r[:images].any? }
      }

      puts "✅ Successfully collected #{count} items from #{platform}"

      # Show sample of first item
      if result[:results].any?
        first = result[:results].first
        puts "   Sample: #{first[:title][0..60]}..."
        puts "   Has images: #{first[:images].present? && first[:images].any?}"
      end
    else
      results_summary[platform] = {
        success: false,
        error: result[:error]
      }
      puts "❌ Failed to collect from #{platform}: #{result[:error]}"
    end

  rescue => e
    results_summary[platform] = {
      success: false,
      error: e.message
    }
    puts "❌ Error collecting from #{platform}: #{e.message}"
  end

  # Small delay between platforms
  sleep 2
end

# Final summary
puts "\n📊 COLLECTION SUMMARY"
puts "=" * 60
puts "Total items collected: #{total_success}"
puts "\nPlatform breakdown:"
results_summary.each do |platform, info|
  if info[:success]
    image_status = info[:has_images] ? "✓ with images" : "✗ no images"
    puts "  #{platform.ljust(15)}: #{info[:count]} items (#{image_status})"
  else
    puts "  #{platform.ljust(15)}: FAILED - #{info[:error]}"
  end
end

# Verify data in database
puts "\n🔍 Database verification:"
puts "  QA Pairs in DB: #{KnowledgeBase::QaPair.count}"

# Check image processing
qa_with_images = KnowledgeBase::QaPair.where("answer LIKE ?", "%[이미지 설명]%").count
puts "  QA Pairs with processed images: #{qa_with_images}"

puts "\n✅ Collection complete!"
