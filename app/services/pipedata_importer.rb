# frozen_string_literal: true

# Pipedata에서 수집된 Excel Q&A 데이터를 가져오는 서비스
class PipedataImporter
  PIPEDATA_PATH = ENV["PIPEDATA_PATH"] || "/Users/kevin/pipedata"
  MIN_QUALITY_SCORE = 0  # 모든 데이터 가져오기

  def import_excel_qa
    imported = 0
    skipped = 0
    failed = 0

    # Pipedata SQLite 데이터베이스 연결
    db_path = File.join(PIPEDATA_PATH, "data", "stackoverflow_analysis.db")

    unless File.exist?(db_path)
      return { success: false, error: "Pipedata database not found at #{db_path}" }
    end

    begin
      # SQLite3 연결
      require "sqlite3"
      db = SQLite3::Database.new(db_path)
      db.results_as_hash = true

      # Excel 관련 질문만 가져오기 (답변이 없으므로)
      query = <<-SQL
        SELECT#{' '}
          q.title as question,
          q.body_markdown as question_body,
          q.score as question_score,
          q.tags,
          q.created_at
        FROM questions q
        WHERE (
          q.tags LIKE '%excel%' OR#{' '}
          q.tags LIKE '%spreadsheet%' OR
          q.title LIKE '%Excel%' OR
          q.title LIKE '%#REF%' OR
          q.title LIKE '%#VALUE%' OR
          q.title LIKE '%VLOOKUP%' OR
          q.title LIKE '%formula%'
        )
        AND q.score >= ?
        ORDER BY q.score DESC
        LIMIT 100
      SQL

      results = db.execute(query, MIN_QUALITY_SCORE)

      results.each do |row|
        # 오류 타입 추출
        error_type = extract_error_type_from_content(row["question"], row["tags"])

        # 카테고리 결정
        category = determine_category(row["question"], row["answer"])

        # 태그 파싱
        tags = parse_tags(row["tags"])

        # 기본 답변 생성 (실제 답변이 없으므로)
        default_answer = generate_default_answer(row["question"], error_type)

        # ErrorPattern 생성
        pattern = ErrorPattern.new(
          question: clean_question(row["question"]),
          answer: default_answer,
          error_type: error_type,
          category: category,
          tags: tags,
          confidence: 0.5, # 답변이 없으므로 낮은 신뢰도
          auto_generated: true, # 자동 생성된 답변
          approved: false, # 검토 필요
          usage_count: 0,
          metadata: {
            source: "pipedata_import",
            original_source: "stackoverflow_questions_only",
            question_score: row["question_score"],
            has_answer: false,
            imported_at: Time.current
          }
        )

        # 시스템 사용자로 생성
        pattern.created_by = User.first

        # 중복 체크
        existing = ErrorPattern.where(
          "question SIMILAR TO ? OR answer SIMILAR TO ?",
          pattern.question.gsub(/[%_]/, '\\\\\0'),
          pattern.answer.gsub(/[%_]/, '\\\\\0')
        ).exists?

        if existing
          skipped += 1
          next
        end

        if pattern.save
          imported += 1

          # Knowledge Base에도 동기화
          sync_to_knowledge_base(pattern)
        else
          failed += 1
          Rails.logger.error "Failed to import pattern: #{pattern.errors.full_messages.join(', ')}"
        end
      end

      db.close

      {
        success: true,
        imported: imported,
        skipped: skipped,
        failed: failed
      }

    rescue SQLite3::Exception => e
      Rails.logger.error "Pipedata import error: #{e.message}"
      { success: false, error: e.message }
    rescue LoadError
      { success: false, error: "sqlite3 gem not installed. Add it to Gemfile for Pipedata import." }
    end
  end

  private

  def extract_error_type_from_content(question, tags)
    content = "#{question} #{tags}".downcase

    error_types = {
      "ref_error" => [ "#ref", "reference error", "deleted cell" ],
      "value_error" => [ "#value", "value error", "wrong type" ],
      "div_zero" => [ "#div/0", "division by zero" ],
      "na_error" => [ "#n/a", "vlookup not found", "lookup failed" ],
      "name_error" => [ "#name", "name error", "undefined name" ],
      "circular_reference" => [ "circular reference", "circular dependency" ],
      "data_type_mismatch" => [ "type mismatch", "data type", "format error" ]
    }

    error_types.each do |type, keywords|
      return type if keywords.any? { |kw| content.include?(kw) }
    end

    "other"
  end

  def determine_category(question, answer = nil)
    # 질문과 답변 기반 카테고리 결정
    if question.match?(/version|compatibility/i)
      "version_pattern"
    elsif question.match?(/finance|accounting|budget/i)
      "domain_pattern"
    elsif answer && answer.include?("=") && answer.match?(/[A-Z]+\(/)
      "error_pattern"
    else
      "error_pattern"
    end
  end

  def parse_tags(tag_string)
    return [] unless tag_string

    tag_string.split(",").map(&:strip).select do |tag|
      tag.match?(/excel|formula|function|error|spreadsheet/i)
    end
  end

  def clean_question(question)
    # HTML 태그 제거 및 정리
    question
      .gsub(/<[^>]+>/, "")
      .gsub(/\s+/, " ")
      .strip
      .truncate(1000)
  end

  def clean_answer(answer)
    # 코드 블록 보존하면서 HTML 정리
    answer
      .gsub(/<code>/, "`")
      .gsub(/<\/code>/, "`")
      .gsub(/<[^>]+>/, "")
      .gsub(/\s+/, " ")
      .strip
  end

  def calculate_confidence(question_score, answer_score = 0)
    # 점수 기반 신뢰도 계산
    total_score = question_score + answer_score

    case total_score
    when 0..10 then 0.6
    when 11..50 then 0.7
    when 51..100 then 0.8
    when 101..500 then 0.9
    else 0.95
    end
  end

  def generate_default_answer(question, error_type)
    # 질문 유형에 따른 기본 답변 생성
    base_answer = "이 문제는 Excel에서 자주 발생하는 오류입니다.\n\n"

    case error_type
    when "ref_error"
      base_answer + "참조 오류(#REF!)는 일반적으로 삭제된 셀이나 범위를 참조할 때 발생합니다. 수식의 참조를 확인하고 유효한 범위로 수정하세요."
    when "value_error"
      base_answer + "값 오류(#VALUE!)는 잘못된 데이터 타입을 사용할 때 발생합니다. 텍스트와 숫자가 올바르게 구분되어 있는지 확인하세요."
    when "formula_error"
      base_answer + "수식 오류는 문법이나 함수 사용법이 잘못되었을 때 발생합니다. Excel 도움말에서 정확한 함수 구문을 확인하세요."
    else
      base_answer + "구체적인 해결 방법은 Excel 버전과 상황에 따라 다를 수 있습니다. 더 자세한 정보가 필요하면 전문가의 도움을 받으세요."
    end
  end

  def sync_to_knowledge_base(pattern)
    KnowledgeBase::QaPair.create!(
      question: pattern.question,
      answer: pattern.answer,
      source: "error_pattern_#{pattern.id}",
      metadata: pattern.to_qa_pair[:metadata]
    )
  rescue => e
    Rails.logger.warn "Failed to sync to knowledge base: #{e.message}"
  end
end
