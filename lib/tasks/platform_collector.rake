# frozen_string_literal: true

namespace :platform_collector do
  desc "Collect data from Stack Overflow, Reddit, or Oppadu"
  task :collect, [ :platform, :limit ] => :environment do |t, args|
    platform = args[:platform]
    limit = (args[:limit] || 10).to_i

    unless platform
      puts "❌ Platform을 지정하세요"
      puts "사용법: rails platform_collector:collect[stackoverflow,10]"
      puts "지원 플랫폼: stackoverflow, reddit, oppadu"
      exit
    end

    puts "=== #{platform.capitalize} 데이터 수집 ==="
    puts "수집 개수: #{limit}"

    collector = PlatformDataCollector.new(platform)
    result = collector.collect_data(limit)

    if result[:success]
      puts "✅ 성공!"
      puts "메시지: #{result[:message]}" if result[:message]
      puts "수집된 항목: #{result[:results].size}" if result[:results]

      # 저장 상태 표시
      if result[:save_status]
        save_status = result[:save_status]
        if save_status[:success]
          puts "\n💾 저장 완료:"
          puts "  - 새로운 항목: #{save_status[:new_items]}"
          puts "  - 중복 제거: #{save_status[:duplicates]}"
          puts "  - 전체 항목: #{save_status[:total_items]}"
          puts "  - 파일 위치: #{save_status[:filepath]}"
        else
          puts "\n⚠️ 저장 실패: #{save_status[:error]}"
        end
      end
    else
      puts "❌ 실패!"
      puts "오류: #{result[:error]}"
    end
  end

  desc "Test all platforms"
  task test_all: :environment do
    platforms = %w[stackoverflow reddit oppadu]

    puts "=== 모든 플랫폼 테스트 ==="

    platforms.each do |platform|
      puts "\n--- #{platform.capitalize} ---"

      begin
        collector = PlatformDataCollector.new(platform)
        result = collector.collect_data(5) # 테스트용으로 5개만

        if result[:success]
          puts "✅ 성공: #{result[:message] || '데이터 수집 완료'}"
        else
          puts "❌ 실패: #{result[:error]}"
        end
      rescue => e
        puts "❌ 오류: #{e.message}"
      end
    end
  end

  desc "Generate daily summary"
  task daily_summary: :environment do
    puts "=== 일일 데이터 수집 요약 ==="

    saver = PlatformDataSaver.new
    summary = saver.generate_daily_summary

    puts "\n📅 날짜: #{summary[:date]}"
    puts "\n📊 전체 통계:"
    puts "  - 총 항목 수: #{summary[:totals][:items]}"
    puts "  - 이미지 포함: #{summary[:totals][:with_images]}"
    puts "  - VBA 코드: #{summary[:totals][:with_vba]}"
    puts "  - 테이블: #{summary[:totals][:with_tables]}"
    puts "  - 수식: #{summary[:totals][:with_formulas]}"

    puts "\n📈 플랫폼별 상세:"
    summary[:platforms].each do |platform, stats|
      puts "\n#{platform.capitalize}:"
      if stats[:status] == "no_data_today"
        puts "  ❌ 오늘 수집된 데이터 없음"
      else
        puts "  - 전체 항목: #{stats[:total_items]}"
        puts "  - 오늘 수집 횟수: #{stats[:collections_today]}"
        puts "  - 마지막 수집: #{stats[:last_collection]}"
        puts "  - 평균 답변 길이: #{stats[:avg_answer_length].to_i}자"
      end
    end
  end

  desc "Check API configuration"
  task check_config: :environment do
    puts "=== API 설정 확인 ==="

    # Stack Overflow
    so_key = ENV["STACKOVERFLOW_API_KEY"]
    puts "\nStack Overflow:"
    puts "  API Key: #{so_key.present? ? '✅ 설정됨' : '❌ 없음'}"

    # Reddit
    reddit_id = ENV["REDDIT_CLIENT_ID"]
    reddit_secret = ENV["REDDIT_CLIENT_SECRET"]
    puts "\nReddit:"
    puts "  Client ID: #{reddit_id.present? ? '✅ 설정됨' : '❌ 없음'}"
    puts "  Client Secret: #{reddit_secret.present? ? '✅ 설정됨' : '❌ 없음'}"

    # Oppadu
    puts "\n오빠두 (Oppadu):"
    puts "  API 불필요 (웹 스크래핑 사용 예정)"

    # Pipedata
    pipedata_path = ENV["PIPEDATA_PATH"] || "/Users/kevin/pipedata"
    db_exists = File.exist?(File.join(pipedata_path, "data", "stackoverflow_analysis.db"))
    puts "\nPipedata (StackOverflow 대체):"
    puts "  Path: #{pipedata_path}"
    puts "  Database: #{db_exists ? '✅ 존재' : '❌ 없음'}"
  end

  desc "Import from Pipedata (StackOverflow local data)"
  task import_pipedata: :environment do
    puts "=== Pipedata에서 StackOverflow 데이터 가져오기 ==="

    importer = PipedataImporter.new
    result = importer.import_excel_qa

    if result[:success]
      puts "✅ 성공!"
      puts "가져온 항목: #{result[:imported]}"
      puts "중복 건너뜀: #{result[:skipped]}"
      puts "실패: #{result[:failed]}"
    else
      puts "❌ 실패!"
      puts "오류: #{result[:error]}"
    end
  end

  desc "Create collection tasks for platforms"
  task create_tasks: :environment do
    user = Authentication::User.find_by(email: "admin@excel-unified.com")

    unless user
      puts "❌ Admin 사용자를 찾을 수 없습니다"
      exit
    end

    # Stack Overflow task
    task1 = DataPipeline::CollectionTask.find_or_create_by(name: "Stack Overflow Excel Q&A") do |t|
      t.task_type = :web_scraping
      t.schedule = :daily
      t.status = :active
      t.source_config = {
        "platform" => "stackoverflow",
        "tags" => [ "excel", "excel-formula", "excel-vba" ],
        "output" => { "type" => "knowledge_base" },
        "max_items_per_run" => 50
      }
      t.created_by = user
    end

    # Reddit task
    task2 = DataPipeline::CollectionTask.find_or_create_by(name: "Reddit r/excel Q&A") do |t|
      t.task_type = :api_fetch
      t.schedule = :daily
      t.status = :paused # API 키 없으므로 일시정지
      t.source_config = {
        "platform" => "reddit",
        "subreddit" => "excel",
        "output" => { "type" => "knowledge_base" },
        "max_items_per_run" => 30
      }
      t.created_by = user
    end

    # Oppadu task
    task3 = DataPipeline::CollectionTask.find_or_create_by(name: "오빠두 Excel 강좌") do |t|
      t.task_type = :web_scraping
      t.schedule = :weekly
      t.status = :paused # 정책 확인 필요
      t.source_config = {
        "platform" => "oppadu",
        "url" => "https://www.oppadu.com",
        "output" => { "type" => "knowledge_base" },
        "max_items_per_run" => 20
      }
      t.created_by = user
    end

    puts "✅ Collection tasks 생성 완료:"
    puts "1. #{task1.name} (ID: #{task1.id}) - Status: #{task1.status}"
    puts "2. #{task2.name} (ID: #{task2.id}) - Status: #{task2.status}"
    puts "3. #{task3.name} (ID: #{task3.id}) - Status: #{task3.status}"
  end
end
