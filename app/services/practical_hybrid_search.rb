# frozen_string_literal: true

# 실용적 하이브리드 검색 서비스
# pgvector (의미적 검색) + PostgreSQL Full-text Search (키워드 검색)
class PracticalHybridSearch
  VECTOR_WEIGHT = 0.6
  FTS_WEIGHT = 0.4
  MIN_SCORE_THRESHOLD = 0.3

  def initialize
    @embedding_service = KnowledgeBase::Services::EmbeddingService.new
  end

  def search(query, options = {})
    limit = options[:limit] || 10

    # 1. 임베딩 생성
    embedding = generate_embedding(query)

    # 2. 병렬로 두 가지 검색 실행
    vector_results = perform_vector_search(query, embedding, limit * 2) if embedding
    fts_results = perform_fts_search(query, limit * 2)

    # 3. 결과 결합 및 재순위
    combined_results = combine_and_rerank(
      vector_results || [],
      fts_results,
      query
    )

    # 4. 상위 N개 반환
    combined_results.first(limit)
  end

  private

  def generate_embedding(query)
    result = @embedding_service.generate_embedding(query)
    result[:embedding] if result[:success]
  rescue => e
    Rails.logger.error "Embedding generation failed: #{e.message}"
    nil
  end

  def perform_vector_search(query, embedding, limit)
    # pgvector를 사용한 의미적 유사성 검색
    ErrorPattern.approved
                .nearest_neighbors(:embedding, embedding, distance: "cosine")
                .limit(limit)
                .map do |pattern|
                  {
                    pattern: pattern,
                    score: calculate_vector_score(pattern, embedding),
                    source: "vector"
                  }
                end
  end

  def perform_fts_search(query, limit)
    # PostgreSQL Full-text Search
    # 한글과 영어 모두 지원
    tsquery = sanitize_tsquery(query)

    ErrorPattern.approved
                .where(
                  "to_tsvector('simple', question || ' ' || answer || ' ' || COALESCE(array_to_string(tags, ' '), '')) @@ to_tsquery('simple', ?)",
                  tsquery
                )
                .limit(limit)
                .map do |pattern|
                  {
                    pattern: pattern,
                    score: calculate_fts_score(pattern, query),
                    source: "fts"
                  }
                end
  rescue => e
    Rails.logger.error "FTS search failed: #{e.message}"
    []
  end

  def sanitize_tsquery(query)
    # 특수문자 제거 및 OR 연산자로 연결
    words = query.split(/\s+/)
                 .map { |w| w.gsub(/[^\w가-힣]/, "") }
                 .reject(&:blank?)
                 .map { |w| "#{w}:*" } # 부분 매칭 지원

    words.join(" | ")
  end

  def combine_and_rerank(vector_results, fts_results, original_query)
    # 패턴별로 점수 집계
    pattern_scores = {}

    # Vector 검색 결과 처리
    vector_results.each do |result|
      pattern_id = result[:pattern].id
      pattern_scores[pattern_id] ||= { pattern: result[:pattern], vector_score: 0, fts_score: 0 }
      pattern_scores[pattern_id][:vector_score] = result[:score]
    end

    # FTS 검색 결과 처리
    fts_results.each do |result|
      pattern_id = result[:pattern].id
      pattern_scores[pattern_id] ||= { pattern: result[:pattern], vector_score: 0, fts_score: 0 }
      pattern_scores[pattern_id][:fts_score] = result[:score]
    end

    # 최종 점수 계산 및 정렬
    pattern_scores.values
                  .map do |data|
                    final_score = (data[:vector_score] * VECTOR_WEIGHT) +
                                 (data[:fts_score] * FTS_WEIGHT)

                    # 추가 부스팅 요소
                    final_score *= boost_factor(data[:pattern], original_query)

                    {
                      pattern: data[:pattern],
                      score: final_score,
                      vector_score: data[:vector_score],
                      fts_score: data[:fts_score]
                    }
                  end
                  .select { |r| r[:score] >= MIN_SCORE_THRESHOLD }
                  .sort_by { |r| -r[:score] }
  end

  def calculate_vector_score(pattern, embedding)
    # 코사인 유사도는 이미 pgvector에서 계산됨
    # 추가적인 정규화만 수행
    base_score = 0.8 # pgvector는 가장 유사한 것부터 반환

    # 신뢰도와 사용 횟수로 조정
    confidence_boost = pattern.confidence * 0.1
    usage_boost = Math.log10(pattern.usage_count + 1) * 0.05

    [ base_score + confidence_boost + usage_boost, 1.0 ].min
  end

  def calculate_fts_score(pattern, query)
    # 키워드 매칭 점수 계산
    query_words = query.downcase.split(/\s+/)
    pattern_text = "#{pattern.question} #{pattern.answer} #{pattern.tags.join(' ')}".downcase

    matched_words = query_words.count { |word| pattern_text.include?(word) }
    base_score = matched_words.to_f / query_words.size

    # 정확한 매칭에 보너스
    exact_match_bonus = pattern.question.downcase.include?(query.downcase) ? 0.2 : 0

    [ base_score + exact_match_bonus, 1.0 ].min
  end

  def boost_factor(pattern, query)
    boost = 1.0

    # 최근 사용된 패턴 부스팅
    if pattern.pattern_usages.any?
      last_used = pattern.pattern_usages.maximum(:created_at)
      days_ago = (Time.current - last_used) / 1.day
      boost *= (1.0 + (1.0 / (days_ago + 1)) * 0.1)
    end

    # 높은 효과성 점수 부스팅
    if pattern.effectiveness_score.present? && pattern.effectiveness_score > 0.8
      boost *= 1.1
    end

    # 승인된 패턴 부스팅
    boost *= 1.05 if pattern.approved?

    # 오류 타입 매칭 부스팅
    error_keywords = {
      "ref_error" => [ "#ref", "ref!", "참조" ],
      "value_error" => [ "#value", "value!", "값" ],
      "div_zero" => [ "#div/0", "div/0!", "0으로 나누기" ]
    }

    error_keywords.each do |error_type, keywords|
      if pattern.error_type == error_type && keywords.any? { |kw| query.downcase.include?(kw) }
        boost *= 1.2
        break
      end
    end

    boost
  end
end
