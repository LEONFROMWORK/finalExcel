#!/usr/bin/env ruby
# Clear all data and recollect from all platforms with proper image processing

require_relative 'config/environment'

puts "🧹 Clearing all data and recollecting with fixed image processing..."
puts "=" * 60

# Clear ALL cache
Rails.cache.clear
puts "✅ Cache cleared"

# Clear all existing data files
date_str = Date.current.strftime('%Y%m%d')
export_dir = Rails.root.join('tmp', 'platform_datasets')

[ 'stackoverflow', 'reddit', 'mrexcel', 'oppadu' ].each do |platform|
  filename = "#{platform}_dataset_#{date_str}.json"
  filepath = export_dir.join(filename)
  if File.exist?(filepath)
    File.delete(filepath)
    puts "✅ Deleted #{filename}"
  end
end

# Define collection limits
collections = [
  { platform: 'stackoverflow', limit: 20 },
  { platform: 'reddit', limit: 20 },
  { platform: 'mrexcel', limit: 20 },
  { platform: 'oppadu', limit: 30 }
]

# Collect from each platform
total_collected = 0
total_with_images = 0

collections.each do |config|
  puts "\n🌐 Collecting #{config[:limit]} items from #{config[:platform].capitalize}..."

  collector = PlatformDataCollector.new(config[:platform])
  result = collector.collect_data(config[:limit])

  if result[:success]
    puts "✅ Collected #{result[:results].size} items"

    # Count items with images
    items_with_images = result[:results].count { |item| item[:images]&.any? }
    puts "📸 Items with images: #{items_with_images}"

    total_collected += result[:results].size
    total_with_images += items_with_images

    if result[:save_status]
      puts "📁 Saved to: #{File.basename(result[:save_status][:filepath])}"
    end
  else
    puts "❌ Failed: #{result[:error]}"
  end

  # Brief pause between platforms
  sleep(2)
end

puts "\n" + "=" * 60
puts "📊 Collection Summary:"
puts "Total items collected: #{total_collected}"
puts "Total items with images: #{total_with_images}"
puts "Image processing rate: #{(total_with_images.to_f / total_collected * 100).round(1)}%"

# Import to database
puts "\n📥 Importing to database..."
importer = Rails.root.join('lib', 'tasks', 'scripts', 'import_collected_to_db.rb')
if File.exist?(importer)
  load importer
  puts "✅ Database import completed"
else
  puts "⚠️  Import script not found"
end

puts "\n✅ All done!"
