# frozen_string_literal: true

namespace :error_patterns do
  desc "Generate rule-based error patterns"
  task generate_rules: :environment do
    puts "Generating rule-based error patterns..."

    generator = ExcelErrorPatternGenerator.new
    result = generator.call

    if result[:success]
      patterns = result[:data][:patterns]
      created_count = 0

      patterns.each do |pattern_data|
        pattern = ErrorPattern.new(
          question: pattern_data[:question],
          answer: pattern_data[:answer],
          error_type: determine_error_type(pattern_data[:tags]),
          category: pattern_data[:category],
          tags: pattern_data[:tags],
          confidence: pattern_data[:confidence],
          auto_generated: true,
          approved: true, # 규칙 기반은 자동 승인
          metadata: {
            generator: "rule_based",
            generated_at: Time.current
          }
        )

        # 첫 번째 사용자를 시스템 사용자로 사용
        pattern.created_by = Authentication::User.first

        if pattern.save
          created_count += 1
          print "."
        else
          print "F"
        end
      end

      puts "\n\nGeneration complete!"
      puts "Total patterns generated: #{patterns.size}"
      puts "Successfully saved: #{created_count}"
      puts "Failed: #{patterns.size - created_count}"

      # 카테고리별 통계
      puts "\nPatterns by category:"
      result[:data][:categories].each do |category, count|
        puts "  #{category}: #{count}"
      end
    else
      puts "Error generating patterns: #{result[:error]}"
    end
  end

  desc "Import patterns from Pipedata"
  task import_pipedata: :environment do
    puts "Importing Excel Q&A from Pipedata..."

    importer = PipedataImporter.new
    result = importer.import_excel_qa

    if result[:success]
      puts "Successfully imported #{result[:imported]} patterns"
      puts "Skipped #{result[:skipped]} duplicates"
      puts "Failed #{result[:failed]} imports"
    else
      puts "Import failed: #{result[:error]}"
    end
  end

  desc "Validate all unvalidated patterns"
  task validate: :environment do
    puts "Validating patterns..."

    unvalidated = ErrorPattern.left_joins(:pattern_validations)
                              .where(pattern_validations: { id: nil })
                              .or(ErrorPattern.joins(:pattern_validations)
                                              .group("error_patterns.id")
                                              .having("MAX(pattern_validations.created_at) < ?", 7.days.ago))

    puts "Found #{unvalidated.count} patterns to validate"

    detector = AiHallucinationDetector.new(nil)

    unvalidated.find_each do |pattern|
      detector = AiHallucinationDetector.new(pattern)
      result = detector.call

      if result[:success]
        print result[:data][:valid] ? "." : "F"
      else
        print "E"
      end
    end

    puts "\nValidation complete!"
  end

  desc "Generate statistics report"
  task stats: :environment do
    puts "\n=== Error Pattern Statistics ==="
    puts "Total patterns: #{ErrorPattern.count}"
    puts "Auto-generated: #{ErrorPattern.auto_generated.count}"
    puts "Manual: #{ErrorPattern.manual.count}"
    puts "Approved: #{ErrorPattern.approved.count}"
    puts "Pending: #{ErrorPattern.pending.count}"

    puts "\n=== By Error Type ==="
    ErrorPattern.group(:error_type).count.each do |type, count|
      puts "  #{type}: #{count}"
    end

    puts "\n=== By Category ==="
    ErrorPattern.group(:category).count.each do |category, count|
      puts "  #{category}: #{count}"
    end

    puts "\n=== Usage Statistics ==="
    puts "Total uses: #{ErrorPatternUsage.count}"
    puts "Unique users: #{ErrorPatternUsage.distinct.count(:user_id)}"
    puts "Average feedback: #{ErrorPatternUsage.average(:feedback)&.round(2) || 'N/A'}"
    puts "Resolution rate: #{(ErrorPatternUsage.resolved.count.to_f / ErrorPatternUsage.count * 100).round(2)}%" if ErrorPatternUsage.any?

    puts "\n=== Top 10 Most Used Patterns ==="
    ErrorPattern.order(usage_count: :desc).limit(10).each_with_index do |pattern, idx|
      puts "#{idx + 1}. [#{pattern.error_type}] #{pattern.question.truncate(50)} (#{pattern.usage_count} uses)"
    end
  end

  private

  def determine_error_type(tags)
    error_mapping = {
      "#REF!" => "ref_error",
      "#VALUE!" => "value_error",
      "#DIV/0!" => "div_zero",
      "#N/A" => "na_error",
      "#NAME?" => "name_error",
      "#NULL!" => "null_error",
      "#NUM!" => "num_error",
      "circular_reference" => "circular_reference",
      "data_type_mismatch" => "data_type_mismatch"
    }

    tags.each do |tag|
      return error_mapping[tag] if error_mapping[tag]
    end

    "other"
  end
end
