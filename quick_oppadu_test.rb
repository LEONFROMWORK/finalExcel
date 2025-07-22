#!/usr/bin/env ruby
# Quick Oppadu test - collect just 3 items

require_relative 'config/environment'

puts "⚡ 빠른 오빠두 테스트 (3개만)..."
puts "=" * 60

# Disable resilient collector for speed
ENV['USE_RESILIENT_COLLECTOR'] = 'false'
ENV['SKIP_SELENIUM_OPPADU'] = 'true'

# Clear logs
system("echo '' > log/development.log")

collector = PlatformDataCollector.new('oppadu')
result = collector.collect_data(3)

if result[:success]
  puts "✅ 수집 성공: #{result[:results].size}개"
  
  # Show all results
  result[:results].each_with_index do |item, idx|
    puts "\n#{idx + 1}. #{item[:title]}"
    puts "   질문 길이: #{item[:question]&.length || 0}"
    puts "   답변 길이: #{item[:answer]&.length || 0}"
    puts "   이미지: #{item[:images]&.size || 0}개"
    
    if item[:images]&.any?
      puts "   이미지 URL: #{item[:images].first[:url]}"
      
      # Check answer content
      if item[:answer].include?("AI Vision Processing")
        puts "   ✅ AI 처리 완료"
        # Show snippet of processed content
        ai_content = item[:answer].match(/AI Vision Processing[^:]*: (.{100})/m)
        puts "   내용: #{ai_content[1]}..." if ai_content
      elsif item[:answer].include?("I'm unable to analyze")
        puts "   ❌ AI 처리 실패"
      end
    end
  end
  
  # Check save status
  if result[:save_status]
    puts "\n💾 저장됨: oppadu_dataset_#{Date.current.strftime('%Y%m%d')}.json"
  end
else
  puts "❌ 실패: #{result[:error]}"
end

puts "\n✨ 완료!"