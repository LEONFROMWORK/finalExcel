# frozen_string_literal: true

module Admin
  class ErrorPatternsController < ApplicationController
    before_action :set_pattern, only: [ :show, :edit, :update, :destroy, :approve, :reject ]

    def index
      @patterns = fetch_patterns
      @stats = pattern_statistics
    end

    def new
      @pattern = ErrorPattern.new
    end

    def create
      @pattern = ErrorPattern.new(pattern_params)
      @pattern.created_by = current_admin

      if @pattern.save
        redirect_to admin_error_patterns_path, notice: "오류 패턴이 생성되었습니다."
      else
        render :new
      end
    end

    def show
      @similar_patterns = find_similar_patterns(@pattern)
      @usage_stats = @pattern.usage_statistics
    end

    def generate
      # AI 패턴 생성
      case params[:generation_type]
      when "rule_based"
        generate_rule_based_patterns
      when "ai_synthesis"
        generate_ai_patterns
      when "import_pipedata"
        import_from_pipedata
      else
        redirect_to admin_error_patterns_path, alert: "잘못된 생성 타입입니다."
      end
    end

    def bulk_actions
      pattern_ids = params[:pattern_ids]
      action = params[:bulk_action]

      case action
      when "approve"
        ErrorPattern.where(id: pattern_ids).update_all(approved: true, approved_by_id: current_admin.id, approved_at: Time.current)
        flash[:notice] = "#{pattern_ids.size}개 패턴이 승인되었습니다."
      when "delete"
        ErrorPattern.where(id: pattern_ids).destroy_all
        flash[:notice] = "#{pattern_ids.size}개 패턴이 삭제되었습니다."
      when "export"
        export_patterns(pattern_ids)
        return
      end

      redirect_to admin_error_patterns_path
    end

    def analytics
      @analytics = {
        coverage: calculate_error_coverage,
        effectiveness: measure_pattern_effectiveness,
        trends: analyze_error_trends,
        recommendations: generate_recommendations
      }
    end

    private

    def set_pattern
      @pattern = ErrorPattern.find(params[:id])
    end

    def pattern_params
      params.require(:error_pattern).permit(
        :question, :answer, :error_type, :category,
        :domain, :confidence, :auto_generated,
        tags: [], metadata: {}
      )
    end

    def fetch_patterns
      patterns = ErrorPattern.includes(:created_by, :approved_by)

      # 필터링
      patterns = patterns.where(error_type: params[:error_type]) if params[:error_type].present?
      patterns = patterns.where(category: params[:category]) if params[:category].present?
      patterns = patterns.where(auto_generated: true) if params[:auto_generated] == "true"
      patterns = patterns.where(approved: true) if params[:approved] == "true"

      # 검색
      if params[:search].present?
        patterns = patterns.where(
          "question LIKE ? OR answer LIKE ? OR tags LIKE ?",
          "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%"
        )
      end

      # 정렬
      case params[:sort]
      when "newest"
        patterns = patterns.order(created_at: :desc)
      when "confidence"
        patterns = patterns.order(confidence: :desc)
      when "usage"
        patterns = patterns.order(usage_count: :desc)
      else
        patterns = patterns.order(created_at: :desc)
      end

      patterns.page(params[:page])
    end

    def pattern_statistics
      {
        total: ErrorPattern.count,
        auto_generated: ErrorPattern.where(auto_generated: true).count,
        manual: ErrorPattern.where(auto_generated: false).count,
        approved: ErrorPattern.where(approved: true).count,
        pending: ErrorPattern.where(approved: false).count,
        by_type: ErrorPattern.group(:error_type).count,
        by_category: ErrorPattern.group(:category).count,
        recent_usage: recent_usage_stats
      }
    end

    def generate_rule_based_patterns
      generator = ExcelErrorPatternGenerator.new
      result = generator.call

      if result.success?
        # 생성된 패턴을 DB에 저장
        created_count = 0

        result.data[:patterns].each do |pattern_data|
          pattern = ErrorPattern.create(
            question: pattern_data[:question],
            answer: pattern_data[:answer],
            error_type: extract_error_type(pattern_data[:tags]),
            category: pattern_data[:category],
            tags: pattern_data[:tags],
            confidence: pattern_data[:confidence],
            auto_generated: true,
            created_by: current_admin,
            metadata: {
              generator: "rule_based",
              generated_at: Time.current
            }
          )

          created_count += 1 if pattern.persisted?
        end

        redirect_to admin_error_patterns_path,
                    notice: "#{created_count}개의 규칙 기반 패턴이 생성되었습니다."
      else
        redirect_to admin_error_patterns_path,
                    alert: "패턴 생성 실패: #{result.error}"
      end
    end

    def generate_ai_patterns
      # 기존 패턴을 기반으로 AI 합성
      base_patterns = ErrorPattern.approved.limit(50)

      synthesizer = AiPatternSynthesizer.new(
        base_patterns: base_patterns.map { |p|
          { question: p.question, answer: p.answer, tags: p.tags }
        },
        tier: :pro  # 관리자는 Pro tier 사용
      )

      result = synthesizer.call

      if result.success?
        created_count = 0

        result.data[:patterns].each do |pattern_data|
          pattern = ErrorPattern.create(
            question: pattern_data[:question],
            answer: pattern_data[:answer],
            error_type: extract_error_type(pattern_data[:tags]),
            category: pattern_data[:type],
            domain: pattern_data[:domain],
            tags: pattern_data[:tags],
            confidence: pattern_data[:confidence],
            auto_generated: true,
            created_by: current_admin,
            metadata: {
              generator: "ai_synthesis",
              synthesis_type: pattern_data[:type],
              generated_at: Time.current
            }
          )

          created_count += 1 if pattern.persisted?
        end

        redirect_to admin_error_patterns_path,
                    notice: "#{created_count}개의 AI 합성 패턴이 생성되었습니다."
      else
        redirect_to admin_error_patterns_path,
                    alert: "AI 패턴 생성 실패: #{result.error}"
      end
    end

    def import_from_pipedata
      # Pipedata에서 수집된 Q&A 가져오기
      importer = PipedataImporter.new
      result = importer.import_excel_qa

      if result[:success]
        redirect_to admin_error_patterns_path,
                    notice: "#{result[:imported]}개의 패턴을 Pipedata에서 가져왔습니다."
      else
        redirect_to admin_error_patterns_path,
                    alert: "가져오기 실패: #{result[:error]}"
      end
    end

    def find_similar_patterns(pattern)
      # 유사 패턴 찾기
      ErrorPattern.where.not(id: pattern.id)
                  .where(error_type: pattern.error_type)
                  .limit(5)
    end

    def export_patterns(pattern_ids)
      patterns = ErrorPattern.where(id: pattern_ids)

      csv_data = CSV.generate do |csv|
        csv << [ "ID", "Question", "Answer", "Error Type", "Category", "Tags", "Confidence", "Usage Count" ]

        patterns.each do |pattern|
          csv << [
            pattern.id,
            pattern.question,
            pattern.answer,
            pattern.error_type,
            pattern.category,
            pattern.tags.join(", "),
            pattern.confidence,
            pattern.usage_count
          ]
        end
      end

      send_data csv_data,
                filename: "error_patterns_#{Date.current}.csv",
                type: "text/csv"
    end

    def calculate_error_coverage
      total_error_types = [ "#REF!", "#VALUE!", "#DIV/0!", "#N/A", "#NAME?", "#NULL!", "#NUM!", "circular_reference", "data_type_mismatch" ]
      covered_types = ErrorPattern.distinct.pluck(:error_type)

      {
        total_types: total_error_types.size,
        covered_types: covered_types.size,
        coverage_percentage: (covered_types.size.to_f / total_error_types.size * 100).round(2),
        missing_types: total_error_types - covered_types
      }
    end

    def measure_pattern_effectiveness
      # 패턴 효과성 측정
      patterns_with_usage = ErrorPattern.where("usage_count > 0")

      {
        total_patterns: ErrorPattern.count,
        used_patterns: patterns_with_usage.count,
        usage_rate: (patterns_with_usage.count.to_f / ErrorPattern.count * 100).round(2),
        avg_confidence: ErrorPattern.average(:confidence).round(2),
        top_patterns: ErrorPattern.order(usage_count: :desc).limit(10)
      }
    end

    def analyze_error_trends
      # 최근 30일간 오류 트렌드
      thirty_days_ago = 30.days.ago

      daily_counts = ErrorPattern.where("created_at > ?", thirty_days_ago)
                                 .group_by_day(:created_at)
                                 .count

      {
        daily_counts: daily_counts,
        growth_rate: calculate_growth_rate(daily_counts),
        peak_day: daily_counts.max_by { |_, count| count }&.first,
        total_recent: daily_counts.values.sum
      }
    end

    def generate_recommendations
      recommendations = []

      # 커버리지 기반 권장사항
      coverage = calculate_error_coverage
      if coverage[:coverage_percentage] < 80
        recommendations << {
          type: "coverage",
          priority: "high",
          message: "오류 타입 커버리지가 #{coverage[:coverage_percentage]}%입니다. #{coverage[:missing_types].join(', ')} 패턴을 추가하세요."
        }
      end

      # 사용률 기반 권장사항
      effectiveness = measure_pattern_effectiveness
      if effectiveness[:usage_rate] < 50
        recommendations << {
          type: "usage",
          priority: "medium",
          message: "패턴 사용률이 #{effectiveness[:usage_rate]}%로 낮습니다. 품질 개선이 필요합니다."
        }
      end

      # AI 생성 권장
      auto_generated_ratio = @stats[:auto_generated].to_f / @stats[:total]
      if auto_generated_ratio < 0.7
        recommendations << {
          type: "generation",
          priority: "medium",
          message: "자동 생성 패턴 비율이 #{(auto_generated_ratio * 100).round}%입니다. AI 패턴 생성을 활용하세요."
        }
      end

      recommendations
    end

    def recent_usage_stats
      # 최근 7일간 사용 통계
      ErrorPatternUsage.where("created_at > ?", 7.days.ago)
                       .group_by_day(:created_at)
                       .count
    end

    def extract_error_type(tags)
      error_types = [ "#REF!", "#VALUE!", "#DIV/0!", "#N/A", "#NAME?", "#NULL!", "#NUM!" ]

      tags.find { |tag| error_types.include?(tag) } || "other"
    end

    def calculate_growth_rate(daily_counts)
      return 0 if daily_counts.size < 2

      values = daily_counts.values
      first_week_avg = values.first(7).sum.to_f / 7
      last_week_avg = values.last(7).sum.to_f / 7

      return 0 if first_week_avg == 0

      ((last_week_avg - first_week_avg) / first_week_avg * 100).round(2)
    end
  end
end
