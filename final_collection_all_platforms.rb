#!/usr/bin/env ruby
# Final collection from all platforms with optimized image processing

require_relative 'config/environment'

puts "🚀 Final collection from all platforms with optimized image processing..."
puts "=" * 60

# Clear cache
Rails.cache.clear
puts "✅ Cache cleared"

# Clear existing data files
date_str = Date.current.strftime('%Y%m%d')
export_dir = Rails.root.join('tmp', 'platform_datasets')

['stackoverflow', 'reddit', 'mrexcel', 'oppadu'].each do |platform|
  filename = "#{platform}_dataset_#{date_str}.json"
  filepath = export_dir.join(filename)
  if File.exist?(filepath)
    File.delete(filepath)
    puts "✅ Deleted #{filename}"
  end
end

# Collection configuration
collections = [
  { platform: 'stackoverflow', limit: 20 },
  { platform: 'reddit', limit: 20 },
  { platform: 'mrexcel', limit: 20 },
  { platform: 'oppadu', limit: 30 }
]

# Results summary
summary = {
  total_collected: 0,
  total_with_images: 0,
  successful_image_analyses: 0,
  failed_image_analyses: 0,
  platforms: {}
}

# Collect from each platform
collections.each do |config|
  puts "\n" + "=" * 60
  puts "🌐 Collecting #{config[:limit]} items from #{config[:platform].capitalize}..."
  
  start_time = Time.now
  collector = PlatformDataCollector.new(config[:platform])
  result = collector.collect_data(config[:limit])
  elapsed = (Time.now - start_time).round(2)
  
  if result[:success]
    puts "✅ Collected #{result[:results].size} items in #{elapsed}s"
    
    # Analyze image processing results
    platform_stats = {
      collected: result[:results].size,
      with_images: 0,
      successful_analyses: 0,
      failed_analyses: 0
    }
    
    result[:results].each do |item|
      if item[:images]&.any?
        platform_stats[:with_images] += 1
        
        # Check answer for image processing results
        if item[:answer].include?('[이미지 설명]')
          descriptions = item[:answer].scan(/이미지 \d+ \([^)]+\): (.+?)(?=\n이미지 \d+|$)/m)
          
          descriptions.each do |(desc)|
            if desc.include?("I'm unable to analyze") || desc.include?("unable to access")
              platform_stats[:failed_analyses] += 1
            else
              platform_stats[:successful_analyses] += 1
            end
          end
        end
      end
    end
    
    summary[:platforms][config[:platform]] = platform_stats
    summary[:total_collected] += platform_stats[:collected]
    summary[:total_with_images] += platform_stats[:with_images]
    summary[:successful_image_analyses] += platform_stats[:successful_analyses]
    summary[:failed_image_analyses] += platform_stats[:failed_analyses]
    
    puts "📸 Items with images: #{platform_stats[:with_images]}"
    puts "✅ Successful image analyses: #{platform_stats[:successful_analyses]}"
    puts "❌ Failed image analyses: #{platform_stats[:failed_analyses]}"
    
    if result[:save_status]
      puts "📁 Saved to: #{File.basename(result[:save_status][:filepath])}"
    end
  else
    puts "❌ Failed: #{result[:error]}"
    summary[:platforms][config[:platform]] = { error: result[:error] }
  end
  
  # Brief pause between platforms
  sleep(2)
end

# Final summary
puts "\n" + "=" * 60
puts "📊 FINAL COLLECTION SUMMARY"
puts "=" * 60
puts "Total items collected: #{summary[:total_collected]}"
puts "Total items with images: #{summary[:total_with_images]}"
puts "Successful image analyses: #{summary[:successful_image_analyses]}"
puts "Failed image analyses: #{summary[:failed_image_analyses]}"

if summary[:total_with_images] > 0
  success_rate = (summary[:successful_image_analyses].to_f / 
                  (summary[:successful_image_analyses] + summary[:failed_image_analyses]) * 100).round(1)
  puts "Image analysis success rate: #{success_rate}%"
end

puts "\nPlatform breakdown:"
summary[:platforms].each do |platform, stats|
  if stats[:error]
    puts "  #{platform.capitalize}: ❌ Error - #{stats[:error]}"
  else
    puts "  #{platform.capitalize}: #{stats[:collected]} items, #{stats[:with_images]} with images " +
         "(✅ #{stats[:successful_analyses]} / ❌ #{stats[:failed_analyses]})"
  end
end

# Import to database
puts "\n📥 Importing to database..."
importer = Rails.root.join('lib', 'tasks', 'scripts', 'import_collected_to_db.rb')
if File.exist?(importer)
  load importer
  puts "✅ Database import completed"
else
  puts "⚠️  Import script not found"
end

puts "\n✅ Collection complete!"

# Save summary to file
summary_file = export_dir.join("collection_summary_#{date_str}.json")
File.write(summary_file, JSON.pretty_generate({
  timestamp: Time.current.iso8601,
  summary: summary,
  improvements_applied: [
    "Fixed cache issues for base64 images",
    "Added MIME type detection",
    "Added retry logic with exponential backoff",
    "Added 'detail: high' parameter for better analysis",
    "Added image size optimization (max 768x2000px)",
    "Added base64 validation",
    "Updated prompts for better results"
  ]
}))
puts "\n📊 Summary saved to: collection_summary_#{date_str}.json"