namespace :search do
  desc "Test search performance"
  task benchmark: :environment do
    queries = [
      "Excel 수식 오류 해결 방법",
      "VBA 매크로 실행 안됨",
      "피벗 테이블 만들기",
      "VLOOKUP 함수 사용법",
      "차트 생성 방법"
    ]

    puts "\n=== Search Performance Benchmark ==="
    puts "Testing with #{queries.size} queries\n\n"

    # Test each search mode
    [ :text, :semantic, :hybrid ].each do |mode|
      puts "Testing #{mode.to_s.upcase} search:"

      total_time = 0
      results_count = 0

      queries.each do |query|
        start_time = Time.current

        service = OptimizedSearchService.new(query, mode: mode, limit: 10)
        results = service.search

        elapsed = Time.current - start_time
        total_time += elapsed
        results_count += results.size

        puts "  Query: '#{query}' - Found: #{results.size} results in #{(elapsed * 1000).round(2)}ms"
      end

      avg_time = (total_time / queries.size * 1000).round(2)
      avg_results = (results_count.to_f / queries.size).round(1)

      puts "  Average: #{avg_time}ms per query, #{avg_results} results per query"
      puts
    end
  end

  desc "Compare search results quality"
  task compare: :environment do
    query = ENV["QUERY"] || "Excel 수식 오류"

    puts "\n=== Search Results Comparison ==="
    puts "Query: '#{query}'\n\n"

    [ :text, :semantic, :hybrid ].each do |mode|
      puts "#{mode.to_s.upcase} Search Results:"

      service = OptimizedSearchService.new(query, mode: mode, limit: 5)
      results = service.search

      if results.empty?
        puts "  No results found"
      else
        results.each_with_index do |result, i|
          puts "  #{i + 1}. [Score: #{result.quality_score}] #{result.question[0..60]}..."
          puts "     Answer: #{result.answer[0..80]}..."
        end
      end
      puts
    end
  end

  desc "Analyze pgvector index usage"
  task analyze_indexes: :environment do
    puts "\n=== PGVector Index Analysis ==="

    # Check if indexes exist
    indexes_sql = <<-SQL
      SELECT#{' '}
        schemaname,
        tablename,
        indexname,
        indexdef
      FROM pg_indexes
      WHERE indexname LIKE '%embedding%'
      ORDER BY tablename, indexname;
    SQL

    results = ActiveRecord::Base.connection.execute(indexes_sql)

    puts "Embedding Indexes:"
    results.each do |row|
      puts "  Table: #{row['tablename']}"
      puts "  Index: #{row['indexname']}"
      puts "  Definition: #{row['indexdef']}"
      puts
    end

    # Check index sizes
    size_sql = <<-SQL
      SELECT#{' '}
        c.relname AS index_name,
        pg_size_pretty(pg_relation_size(c.oid)) AS index_size,
        idx.indnatts AS number_of_columns
      FROM pg_index idx
      JOIN pg_class c ON c.oid = idx.indexrelid
      WHERE c.relname LIKE '%embedding%'
      ORDER BY pg_relation_size(c.oid) DESC;
    SQL

    results = ActiveRecord::Base.connection.execute(size_sql)

    puts "Index Sizes:"
    results.each do |row|
      puts "  #{row['index_name']}: #{row['index_size']}"
    end
  end
end
