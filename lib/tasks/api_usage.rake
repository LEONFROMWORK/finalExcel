# frozen_string_literal: true

namespace :api_usage do
  desc "Display API usage statistics"
  task stats: :environment do
    puts "\n=== API Usage Statistics ==="
    puts "Generated at: #{Time.current}"
    puts "=" * 50
    
    # Today's usage
    today_stats = ApiUsageTracker.usage_stats(:today)
    puts "\nToday's Usage:"
    puts "- Total requests: #{today_stats[:total_requests]}"
    puts "- Total tokens: #{today_stats[:total_tokens].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    puts "- Total cost: $#{today_stats[:total_cost]}"
    
    # This month's usage
    month_stats = ApiUsageTracker.usage_stats(:this_month)
    puts "\nThis Month's Usage:"
    puts "- Total requests: #{month_stats[:total_requests]}"
    puts "- Total tokens: #{month_stats[:total_tokens].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    puts "- Total cost: $#{month_stats[:total_cost]}"
    
    # By service
    if month_stats[:by_service].any?
      puts "\nCost by Service:"
      month_stats[:by_service].each do |service, cost|
        puts "- #{service}: $#{cost}"
      end
    end
    
    # By model
    if month_stats[:by_model].any?
      puts "\nCost by Model:"
      month_stats[:by_model].each do |model, cost|
        puts "- #{model}: $#{cost}"
      end
    end
    
    # Cost projection
    projection = month_stats[:cost_projection]
    if projection && projection[:based_on_days] > 0
      puts "\nCost Projection:"
      puts "- Daily average: $#{projection[:daily_average]}"
      puts "- Monthly projection: $#{projection[:monthly_projection]}"
      puts "- Based on #{projection[:based_on_days]} days of data"
    end
    
    # Check warnings
    warnings = ApiUsageTracker.check_usage_limits
    if warnings.any?
      puts "\n⚠️  Warnings:"
      warnings.each do |warning|
        icon = warning[:level] == :critical ? "🚨" : "⚠️"
        puts "#{icon} #{warning[:message]}"
      end
    else
      puts "\n✅ All usage within normal limits"
    end
    
    puts "\n" + "=" * 50
  end
  
  desc "Export usage data to CSV"
  task export: :environment do
    require 'csv'
    
    filename = "api_usage_#{Date.current}.csv"
    
    CSV.open(filename, "wb") do |csv|
      csv << ["Date", "Service", "Model", "Tokens", "Cost", "Request Type"]
      
      ApiUsageTracker.this_month.order(:created_at).each do |usage|
        csv << [
          usage.created_at.strftime("%Y-%m-%d %H:%M:%S"),
          usage.service,
          usage.model,
          usage.tokens_used,
          usage.cost.round(6),
          usage.request_type
        ]
      end
    end
    
    puts "Usage data exported to #{filename}"
  end
  
  desc "Test API usage tracking"
  task test: :environment do
    puts "Testing API usage tracking..."
    
    # Simulate embedding usage
    test_text = "This is a test text for embedding generation"
    
    puts "\nTracking test embedding..."
    ApiUsageTracker.track_embedding(test_text)
    
    # Show latest entry
    latest = ApiUsageTracker.last
    if latest
      puts "\nLatest tracking entry:"
      puts "- Service: #{latest.service}"
      puts "- Model: #{latest.model}"
      puts "- Tokens: #{latest.tokens_used}"
      puts "- Cost: $#{latest.cost.round(6)}"
      puts "- Created: #{latest.created_at}"
    end
    
    puts "\nTest complete!"
  end
end