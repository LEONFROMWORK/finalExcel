# frozen_string_literal: true

# 목업 포럼 데이터 수집 서비스 (테스트용)
class MockForumScraperService
  attr_reader :forum_type, :options
  
  # 테스트용 샘플 데이터
  SAMPLE_DATA = [
    {
      title: "VLOOKUP 함수에서 #N/A 오류가 발생합니다",
      content: "VLOOKUP을 사용하는데 계속 #N/A 오류가 나옵니다. 데이터는 분명히 있는데 왜 못 찾는 걸까요? 

해결방법: 
1. 찾는 값과 테이블의 첫 번째 열 데이터 형식이 일치하는지 확인하세요 (텍스트 vs 숫자)
2. 공백 문자가 있는지 확인하세요. TRIM 함수를 사용해보세요
3. 정확히 일치하는 값을 찾으려면 네 번째 인수를 FALSE로 설정하세요",
      tags: ["VLOOKUP", "오류해결", "함수"]
    },
    {
      title: "여러 시트의 데이터를 하나로 합치는 방법",
      content: "매달 별도 시트로 관리하는 판매 데이터를 하나의 시트로 통합하고 싶습니다.

Power Query를 사용하는 방법:
1. 데이터 탭 > 데이터 가져오기 > 파일에서 > 통합 문서에서
2. 통합할 시트들을 선택
3. 데이터 변환에서 필요한 처리 수행
4. 닫기 및 로드

VBA를 사용하는 방법도 있지만 Power Query가 더 간단합니다.",
      tags: ["데이터통합", "PowerQuery", "VBA"]
    },
    {
      title: "조건부 서식으로 중복값 찾기",
      content: "열에서 중복된 값을 시각적으로 표시하고 싶어요.

조건부 서식 사용법:
1. 중복을 찾을 범위 선택
2. 홈 탭 > 조건부 서식 > 셀 규칙 강조 표시 > 중복 값
3. 원하는 서식 선택

COUNTIF 함수를 사용한 고급 방법:
=COUNTIF($A:$A,$A1)>1 수식으로 조건부 서식 규칙을 만들 수 있습니다.",
      tags: ["조건부서식", "중복값", "COUNTIF"]
    },
    {
      title: "피벗 테이블 새로고침이 안 됩니다",
      content: "데이터를 업데이트했는데 피벗 테이블에 반영이 안 돼요.

해결 방법:
1. 피벗 테이블 선택 > 분석 탭 > 새로 고침
2. 데이터 원본 범위 확인: 분석 탭 > 데이터 원본 변경
3. 동적 범위 사용: 테이블로 변환하거나 OFFSET 함수 사용
4. VBA로 자동 새로고침: Worksheet_Change 이벤트 활용",
      tags: ["피벗테이블", "새로고침", "데이터원본"]
    },
    {
      title: "INDEX MATCH vs VLOOKUP 성능 비교",
      content: "대용량 데이터에서 VLOOKUP이 느려서 INDEX MATCH로 바꾸려고 합니다.

INDEX MATCH 장점:
1. 왼쪽 방향 조회 가능
2. 열 삽입/삭제에 강함
3. 대용량 데이터에서 더 빠름
4. 메모리 사용량 적음

예제:
=INDEX(반환열,MATCH(찾는값,조회열,0))

XLOOKUP (Excel 365)도 고려해보세요!",
      tags: ["INDEX", "MATCH", "VLOOKUP", "성능"]
    }
  ]
  
  def initialize(forum_type = 'mock', options = {})
    @forum_type = forum_type
    @options = options
  end
  
  def scrape_test(test_url = nil)
    {
      success: true,
      url: test_url || "mock://forum/test",
      forum_type: @forum_type,
      results_count: SAMPLE_DATA.count,
      results: SAMPLE_DATA.map.with_index do |data, index|
        {
          index: index + 1,
          title: data[:title],
          link: "mock://forum/post/#{index + 1}",
          content_preview: data[:content].first(200) + "...",
          scraped_at: Time.current
        }
      end
    }
  end
  
  def scrape_and_save(max_pages: 1)
    results = {
      total_scraped: 0,
      total_saved: 0,
      errors: []
    }
    
    puts "목업 데이터로 테스트 수집을 시작합니다..."
    
    # 각 페이지당 샘플 데이터 저장
    max_pages.times do |page|
      SAMPLE_DATA.each_with_index do |data, index|
        begin
          # 페이지별로 약간 다른 데이터 생성
          modified_title = "#{data[:title]} (페이지 #{page + 1})"
          
          qa_pair = save_as_qa(
            modified_title,
            data[:content],
            "mock://forum/page/#{page + 1}/post/#{index + 1}",
            data[:tags]
          )
          
          results[:total_scraped] += 1
          results[:total_saved] += 1 if qa_pair
          
          # 진행 상황 표시
          print "."
          
        rescue => e
          results[:errors] << { 
            title: modified_title, 
            error: e.message 
          }
        end
      end
      
      puts "\n페이지 #{page + 1} 완료"
    end
    
    results
  end
  
  private
  
  def save_as_qa(title, content, source_url, tags = [])
    # 중복 체크
    existing = KnowledgeBase::QaPair.where(question: title).first
    return existing if existing
    
    # 저장
    qa_pair = KnowledgeBase::QaPair.create!(
      question: title,
      answer: content,
      source: 'user_generated', # 허용된 source 값 사용
      metadata: {
        source_url: source_url,
        scraped_at: Time.current,
        forum_type: @forum_type,
        tags: tags,
        original_source: @forum_type # 원본 소스 정보는 metadata에 저장
      }
    )
    
    # 임베딩 생성 (선택적)
    if @options[:create_embeddings]
      VectorEmbeddingService.new.create_embedding_for_qa(qa_pair)
    end
    
    puts "✓ 저장됨: #{title}"
    qa_pair
  rescue => e
    puts "✗ 저장 실패: #{e.message}"
    Rails.logger.error "Failed to save Q&A: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    nil
  end
end