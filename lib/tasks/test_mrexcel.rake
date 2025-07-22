# frozen_string_literal: true

namespace :data_collection do
  desc "Test MrExcel data collection"
  task test_mrexcel: :environment do
    puts "=== Testing MrExcel Data Collection ==="

    collector = PlatformDataCollector.new("mrexcel")
    result = collector.collect_data(3) # Collect 3 solved threads

    if result[:success]
      puts "✅ Success: #{result[:message]}"
      puts "\n📊 Results:"

      result[:results].each_with_index do |item, index|
        puts "\n#{index + 1}. #{item[:title]}"
        puts "   Link: #{item[:link]}"
        puts "   Tags: #{item[:tags].join(', ')}"
        puts "   Has images: #{item[:images].any? ? 'Yes' : 'No'}"
        puts "   Question preview: #{item[:question][0..100]}..."
        puts "   Answer preview: #{item[:answer][0..100]}..."
      end

      # Test with image analysis if configured
      if ENV["OPENROUTER_API_KEY"].present?
        puts "\n=== Testing with Image Analysis ==="
        enhanced_collector = EnhancedPlatformCollector.new("mrexcel")
        enhanced_result = enhanced_collector.collect_data(1)

        if enhanced_result[:success] && enhanced_result[:results].any?
          item = enhanced_result[:results].first
          puts "\n📸 Image Analysis Results:"
          puts "   Title: #{item[:title]}"

          if item[:image_analyses]&.any?
            item[:image_analyses].each do |analysis|
              puts "\n   Image: #{analysis[:url]}"
              puts "   Excel content: #{analysis[:contains_excel_data] ? 'Yes' : 'No'}"
              puts "   Errors found: #{analysis[:excel_errors].join(', ')}" if analysis[:excel_errors]&.any?
            end
          else
            puts "   No images found or analyzed"
          end
        end
      end

    else
      puts "❌ Error: #{result[:error]}"
    end
  end

  desc "Test all platform collectors"
  task test_all: :environment do
    platforms = %w[stackoverflow reddit mrexcel]

    platforms.each do |platform|
      puts "\n=== Testing #{platform.capitalize} ==="

      collector = PlatformDataCollector.new(platform)
      result = collector.collect_data(2)

      if result[:success]
        puts "✅ Success: #{result[:message]}"
        puts "   Items collected: #{result[:results].size}"
      else
        puts "❌ Error: #{result[:error]}"
      end
    end
  end

  desc "Create collection task for MrExcel"
  task create_mrexcel_task: :environment do
    admin = Authentication::User.find_by(email: "admin@excel-unified.com")

    unless admin
      puts "❌ Admin user not found"
      exit
    end

    task = DataPipeline::CollectionTask.create!(
      name: "MrExcel Forum Collection - #{Date.current}",
      task_type: "web_scraping",
      schedule: "manual",
      source_config: {
        "url" => "https://www.mrexcel.com/board/forums/excel-questions.10/",
        "platform" => "mrexcel",
        "enable_image_analysis" => true,
        "max_items_per_run" => 10
      },
      created_by: admin,
      status: "active"
    )

    puts "✅ Created collection task: #{task.name} (ID: #{task.id})"
    puts "   Platform: MrExcel"
    puts "   Image analysis: Enabled"
    puts "   Status: #{task.status}"
  end
end
