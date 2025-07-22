namespace :forum_scraper do
  desc "Test forum scraping functionality"
  task test: :environment do
    puts "=== Forum Scraper Test ==="
    puts "Testing with mock data..."
    
    # Mock 데이터로 테스트
    scraper = MockForumScraperService.new('mock')
    result = scraper.scrape_test
    
    if result[:success]
      puts "\n✅ 테스트 성공!"
      puts "수집된 게시글 수: #{result[:results_count]}"
      puts "\n게시글 목록:"
      
      result[:results].each do |post|
        puts "\n#{post[:index]}. #{post[:title]}"
        puts "   링크: #{post[:link]}"
        if post[:content_preview]
          puts "   내용 미리보기: #{post[:content_preview]}"
        elsif post[:content_error]
          puts "   ❌ 내용 수집 오류: #{post[:content_error]}"
        end
      end
    else
      puts "\n❌ 테스트 실패!"
      puts "오류: #{result[:error]}"
      puts "상세:"
      result[:backtrace]&.each { |line| puts "  #{line}" }
    end
  end
  
  desc "Run actual forum scraping (limited)"
  task :scrape, [:pages] => :environment do |t, args|
    pages = (args[:pages] || 1).to_i
    puts "=== Forum Scraping Start ==="
    puts "수집할 페이지 수: #{pages}"
    
    # 목업 데이터로 테스트 (실제 운영시 ForumScraperService 사용)
    scraper = MockForumScraperService.new('mock')
    
    puts "\n수집을 시작합니다..."
    start_time = Time.current
    
    results = scraper.scrape_and_save(max_pages: pages)
    
    end_time = Time.current
    duration = (end_time - start_time).round(2)
    
    puts "\n=== 수집 완료 ==="
    puts "소요 시간: #{duration}초"
    puts "수집된 게시글: #{results[:total_scraped]}"
    puts "저장된 Q&A: #{results[:total_saved]}"
    puts "오류 발생: #{results[:errors].count}"
    
    if results[:errors].any?
      puts "\n오류 상세:"
      results[:errors].first(5).each do |error|
        puts "- #{error[:url]}: #{error[:error]}"
      end
    end
    
    # 저장된 데이터 샘플 확인
    puts "\n최근 저장된 Q&A 샘플:"
    KnowledgeBase::QaPair.order(created_at: :desc).limit(3).each_with_index do |qa, i|
      puts "\n#{i + 1}. Q: #{qa.question}"
      puts "   A: #{qa.answer.first(100)}..."
      puts "   출처: #{qa.metadata['source_url']}"
    end
  end
  
  desc "Check collected data statistics"
  task stats: :environment do
    puts "=== 수집 데이터 통계 ==="
    
    total = KnowledgeBase::QaPair.count
    by_source = KnowledgeBase::QaPair.group(:source).count
    recent = KnowledgeBase::QaPair.where('created_at > ?', 1.day.ago).count
    
    puts "\n전체 Q&A 수: #{total}"
    puts "최근 24시간 수집: #{recent}"
    
    puts "\n소스별 통계:"
    by_source.each do |source, count|
      puts "- #{source}: #{count}개"
    end
    
    # 벡터 DB 상태
    vector_count = KnowledgeBase::QaPair.where.not(embedding: nil).count
    puts "\n벡터 임베딩 생성됨: #{vector_count}/#{total} (#{(vector_count.to_f / total * 100).round(2)}%)"
    
    # 최근 수집 데이터
    puts "\n최근 수집된 Q&A (5개):"
    KnowledgeBase::QaPair.order(created_at: :desc).limit(5).each_with_index do |qa, i|
      puts "\n#{i + 1}. [#{qa.created_at.strftime('%Y-%m-%d %H:%M')}]"
      puts "   Q: #{qa.question.first(80)}..."
      puts "   소스: #{qa.source}"
    end
  end
  
  desc "Create collection task for forum scraping"
  task create_task: :environment do
    puts "=== Collection Task 생성 ==="
    
    # 관리자 계정 찾기
    admin = Authentication::User.find_by(email: 'admin@excel-unified.com')
    unless admin
      puts "❌ 관리자 계정이 없습니다. 먼저 관리자를 생성하세요:"
      puts "   rails db:seed"
      exit
    end
    
    # Excel Forum 수집 작업 생성
    task = DataPipeline::CollectionTask.create!(
      name: "Excel Forum Q&A Collection",
      description: "Excel 관련 포럼에서 Q&A 데이터 수집",
      task_type: "web_scraping",
      schedule: "daily",
      status: "active",
      source_config: {
        url: "https://www.excelforum.com/forums/excel-questions/",
        parser: "forum_scraper",
        forum_type: "excelforum",
        max_pages_per_run: 5,
        output: {
          type: "knowledge_base"
        }
      },
      created_by: admin
    )
    
    puts "\n✅ Collection Task 생성 완료!"
    puts "ID: #{task.id}"
    puts "이름: #{task.name}"
    puts "타입: #{task.task_type}"
    puts "스케줄: #{task.schedule}"
    puts "다음 실행: #{task.next_run_at}"
    
    puts "\n수동 실행 명령어:"
    puts "  rails forum_scraper:run_task[#{task.id}]"
  end
  
  desc "Run collection task manually"
  task :run_task, [:task_id] => :environment do |t, args|
    task_id = args[:task_id]
    
    unless task_id
      puts "❌ Task ID를 입력하세요"
      puts "사용법: rails forum_scraper:run_task[TASK_ID]"
      exit
    end
    
    task = DataPipeline::CollectionTask.find(task_id)
    puts "=== Collection Task 실행 ==="
    puts "작업: #{task.name}"
    
    # Create a new run
    run = task.collection_runs.create!(
      status: :running,
      started_at: Time.current
    )
    
    puts "\n실행 ID: #{run.id}"
    puts "상태: #{run.status}"
    
    # Execute collection directly here instead of using CollectionService
    begin
      # Get URL from task config
      url = task.source_url
      forum_type = task.source_config["forum_type"] || "mock"
      
      # Use the real forum scraper for production
      scraper = ForumScraperService.new(forum_type)
      result = scraper.scrape_test(url)
      
      if result[:success]
        items = result[:results]
        saved_count = 0
        
        items.each do |item|
          question = item[:title]
          answer = item[:content_preview]&.gsub(/\.\.\.$/, '')
          
          next unless question && answer
          
          # Check for duplicates
          existing = KnowledgeBase::QaPair.where(question: question).first
          next if existing
          
          KnowledgeBase::QaPair.create!(
            question: question,
            answer: answer,
            source: "user_generated",
            metadata: {
              collection_task_id: task.id,
              collection_run_id: run.id,
              collected_at: Time.current,
              source_url: item[:link]
            }
          )
          saved_count += 1
        end
        
        # Mark run as completed
        run.mark_as_completed!(
          items_collected: items.size,
          items_processed: saved_count
        )
        
        puts "\n✅ 성공!"
        puts "수집된 항목: #{items.size}"
        puts "저장된 항목: #{saved_count}"
      else
        run.mark_as_failed!(result[:error])
        puts "\n❌ 실패!"
        puts "오류: #{result[:error]}"
      end
    rescue => e
      run.mark_as_failed!(e.message)
      puts "\n❌ 실패!"
      puts "오류: #{e.message}"
    end
  end
end