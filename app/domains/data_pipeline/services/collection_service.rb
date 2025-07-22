# frozen_string_literal: true

require_relative '../../../shared/value_objects/result'

module DataPipeline
  module Services
    class CollectionService
      attr_reader :collection_task, :collection_run, :options

      def initialize(collection_task:, collection_run:, options: {})
        @collection_task = collection_task
        @collection_run = collection_run
        @options = options
      end

      def call
        @collection_run.mark_as_running!

        case collection_task.task_type
        when "web_scraping"
          collect_from_web
        when "api_fetch"
          collect_from_api
        when "file_import"
          import_from_file
        when "database_sync"
          sync_from_database
        else
          Result.failure(error: "Unknown task type: #{collection_task.task_type}", code: :invalid_task_type)
        end
      rescue StandardError => e
        Rails.logger.error "Collection failed: #{e.message}\n#{e.backtrace.join("\n")}"
        @collection_run.mark_as_failed!(e.message, { backtrace: e.backtrace })
        Result.failure(error: e.message, code: :collection_error)
      end

      private

      def collect_from_web
        url = collection_task.source_url
        return Result.failure(error: "No URL configured", code: :missing_config) unless url

        # In production, this would use a web scraping library like Mechanize or Selenium
        items = scrape_website(url)
        processed_items = process_items(items)

        save_collected_data(processed_items)

        @collection_run.mark_as_completed!(
          items_collected: items.size,
          items_processed: processed_items.size
        )

        Result.success(
          data: {
            items_collected: items.size,
            items_processed: processed_items.size,
            data: processed_items
          },
          message: "Successfully collected #{items.size} items"
        )
      end

      def collect_from_api
        endpoint = collection_task.api_endpoint
        return Result.failure(error: "No API endpoint configured", code: :missing_config) unless endpoint

        # Fetch data from API
        response = fetch_from_api(endpoint)
        items = parse_api_response(response)
        processed_items = process_items(items)

        save_collected_data(processed_items)

        @collection_run.mark_as_completed!(
          items_collected: items.size,
          items_processed: processed_items.size
        )

        Result.success(
          data: {
            items_collected: items.size,
            items_processed: processed_items.size,
            data: processed_items
          },
          message: "Successfully fetched #{items.size} items from API"
        )
      end

      def import_from_file
        file_path = collection_task.source_config["file_path"]
        return Result.failure(error: "No file path configured", code: :missing_config) unless file_path

        # Import data from file
        items = read_file_data(file_path)
        processed_items = process_items(items)

        save_collected_data(processed_items)

        @collection_run.mark_as_completed!(
          items_collected: items.size,
          items_processed: processed_items.size
        )

        Result.success(
          data: {
            items_collected: items.size,
            items_processed: processed_items.size,
            data: processed_items
          },
          message: "Successfully imported #{items.size} items from file"
        )
      end

      def sync_from_database
        db_config = collection_task.source_config["database"]
        return Result.failure(error: "No database configuration", code: :missing_config) unless db_config

        # Sync data from external database
        items = fetch_from_database(db_config)
        processed_items = process_items(items)

        save_collected_data(processed_items)

        @collection_run.mark_as_completed!(
          items_collected: items.size,
          items_processed: processed_items.size
        )

        Result.success(
          data: {
            items_collected: items.size,    
            items_processed: processed_items.size,
            data: processed_items
          },
          message: "Successfully synced #{items.size} items from database"
        )
      end

      def scrape_website(url)
        Rails.logger.info "Scraping website: #{url}"

        # Get platform from config
        platform = collection_task.source_config["platform"]
        
        if platform.present?
          # Use platform-specific collector
          collector = if collection_task.source_config["enable_image_analysis"]
                       EnhancedPlatformCollector.new(platform)
                     else
                       PlatformDataCollector.new(platform)
                     end
          
          # Collect data with optional image processing
          result = if collector.respond_to?(:collect_with_images)
                    collector.collect_with_images(collection_task.source_config["max_items_per_run"] || 10)
                  else
                    collector.collect_data(collection_task.source_config["max_items_per_run"] || 10)
                  end
          
          if result[:success]
            result[:results] || []
          else
            Rails.logger.error "Collection failed: #{result[:error]}"
            []
          end
        else
          # Legacy forum scraper support
          forum_type = collection_task.source_config["forum_type"] || "mock"
          scraper = ForumScraperService.new(forum_type)
          result = scraper.scrape_test(url)
          
          if result[:success]
            result[:results].map do |item|
              {
                title: item[:title],
                question: item[:title],
                answer: item[:content_preview]&.gsub(/\.\.\.$/, ''),
                link: item[:link] || item[:source_url],
                source: forum_type,
                metadata: { forum_type: forum_type }
              }
            end
          else
            Rails.logger.error "Scraping failed: #{result[:error]}"
            []
          end
        end
      end

      def fetch_from_api(endpoint)
        # Mock implementation for development
        # In production, use HTTParty or Faraday
        Rails.logger.info "Fetching from API: #{endpoint}"

        {
          status: "success",
          data: [
            { id: 1, question: "How to use SUMIF?", answer: "SUMIF syntax is..." },
            { id: 2, question: "What is XLOOKUP?", answer: "XLOOKUP is a new function..." }
          ]
        }
      end

      def parse_api_response(response)
        return [] unless response[:status] == "success"

        response[:data] || []
      end

      def read_file_data(file_path)
        # Mock implementation for development
        Rails.logger.info "Reading file: #{file_path}"

        # In production, actually read and parse the file
        [
          { question: "Excel 피벗 테이블 만들기", answer: "피벗 테이블 생성 방법..." },
          { question: "조건부 서식 활용", answer: "조건부 서식 설정..." }
        ]
      end

      def fetch_from_database(db_config)
        # Mock implementation for development
        Rails.logger.info "Syncing from database: #{db_config['name']}"

        # In production, connect to external database and fetch data
        [
          { source: "external_db", data: "Excel tips and tricks..." },
          { source: "external_db", data: "Advanced formulas..." }
        ]
      end

      def process_items(items)
        processing_options = collection_task.processing_options

        # Apply filters
        filtered_items = apply_filters(items, processing_options[:filters])

        # Apply transformations
        transformed_items = apply_transformations(filtered_items, processing_options[:transformations])

        transformed_items
      end

      def apply_filters(items, filters)
        return items if filters.blank?

        items.select do |item|
          filters.all? do |key, value|
            item[key.to_sym] == value || item[key.to_s] == value
          end
        end
      end

      def apply_transformations(items, transformations)
        return items if transformations.blank?

        items.map do |item|
          transformed = item.dup

          transformations.each do |transformation|
            case transformation["type"]
            when "lowercase"
              field = transformation["field"]
              transformed[field] = transformed[field].downcase if transformed[field].is_a?(String)
            when "uppercase"
              field = transformation["field"]
              transformed[field] = transformed[field].upcase if transformed[field].is_a?(String)
            when "extract"
              # Extract specific fields
              fields = transformation["fields"]
              transformed = transformed.slice(*fields) if fields.present?
            end
          end

          transformed
        end
      end

      def save_collected_data(items)
        # Save to appropriate location based on task configuration
        output_config = collection_task.source_config["output"] || {}

        case output_config["type"]
        when "knowledge_base"
          save_to_knowledge_base(items)
        when "file"
          save_to_file(items, output_config["path"])
        else
          # Default: save to collection_data table or similar
          Rails.logger.info "Saving #{items.size} items to default storage"
        end
      end

      def save_to_knowledge_base(items)
        saved_count = 0
        
        items.each do |item|
          # Extract question and answer
          question = item[:title] || item[:question]
          answer = item[:answer] || item[:content]
          
          # Enhanced answer with image analysis if available
          if item[:enhanced_answer].present?
            answer = item[:enhanced_answer]
          end
          
          next unless question && answer

          # Determine source based on platform
          source = case item[:source]
                  when 'stackoverflow' then 'stackoverflow'
                  when 'reddit' then 'reddit'
                  when 'oppadu' then 'oppadu'
                  when 'mrexcel' then 'user_generated' # MrExcel data saved as user_generated
                  else 'user_generated'
                  end

          # Check for duplicates
          existing = ::KnowledgeBase::QaPair.where(question: question).first
          next if existing

          begin
            metadata = {
              collection_task_id: collection_task.id,
              collection_run_id: collection_run.id,
              collected_at: Time.current,
              source_url: item[:link] || item[:source_url],
              original_source: "data_pipeline_#{collection_task.id}",
              tags: item[:tags] || [],
              score: item[:score]
            }
            
            # Add platform-specific metadata
            metadata.merge!(item[:metadata]) if item[:metadata].present?
            
            # Add image analysis data if available
            if item[:image_analyses].present?
              metadata[:image_analyses] = item[:image_analyses]
              metadata[:has_images] = true
            end
            
            ::KnowledgeBase::QaPair.create!(
              question: question,
              answer: answer,
              source: source,
              quality_score: calculate_quality_score(item),
              metadata: metadata
            )
            saved_count += 1
          rescue ActiveRecord::RecordInvalid => e
            Rails.logger.error "Failed to save Q&A: #{e.message}"
          end
        end
        
        Rails.logger.info "Saved #{saved_count} items to knowledge base"
        saved_count
      end

      def calculate_quality_score(item)
        # Get base scores
        question_score = item[:metadata]&.dig(:question_score) || item[:score] || 0
        answer_score = item[:metadata]&.dig(:answer_score) || 0
        
        # Platform-specific quality calculation
        score = case item[:source]
                when 'stackoverflow'
                  calculate_stackoverflow_quality(question_score, answer_score, item)
                when 'reddit'
                  calculate_reddit_quality(item)
                when 'mrexcel'
                  calculate_mrexcel_quality(item)
                else
                  calculate_confidence_score(question_score, answer_score)
                end
        
        # Content quality factors
        question = item[:question] || item[:title] || ''
        answer = item[:answer] || ''
        
        # Length-based quality adjustment
        if answer.length < 100
          score -= 0.2  # Penalize very short answers
        elsif answer.length > 500
          score += 0.1  # Bonus for comprehensive answers
        end
        
        # Excel-specific content bonus
        excel_keywords = %w[VLOOKUP HLOOKUP INDEX MATCH SUMIF COUNTIF XLOOKUP FILTER formula cell]
        excel_match_count = excel_keywords.count { |kw| (question + answer).upcase.include?(kw) }
        score += (excel_match_count * 0.02).clamp(0, 0.1)
        
        # Error pattern bonus
        error_patterns = %w[#REF! #VALUE! #NAME? #DIV/0! #N/A #NUM! #NULL!]
        if error_patterns.any? { |err| (question + answer).include?(err) }
          score += 0.05  # Bonus for error-specific content
        end
        
        # Code block bonus
        if answer.include?('```') || answer.include?('=')
          score += 0.05  # Bonus for including formulas or code
        end
        
        # Boost for having images with Excel content
        if item[:image_analyses]&.any? { |img| img[:contains_excel_data] }
          score += 0.1
        end
        
        # Additional quality factors
        if item[:tags]&.any? { |tag| tag.match?(/excel|formula|vba/i) }
          score += 0.05
        end
        
        [score, 1.0].min # Cap at 1.0
      end
      
      def calculate_mrexcel_quality(item)
        # Base score for MrExcel (community-driven forum)
        base_score = 0.7
        
        # Thread metadata factors
        thread_views = item[:metadata]&.dig(:thread_views) || 0
        reply_count = item[:metadata]&.dig(:reply_count) || 0
        
        # View-based bonus
        if thread_views > 10000
          base_score += 0.15
        elsif thread_views > 5000
          base_score += 0.1
        elsif thread_views > 1000
          base_score += 0.05
        end
        
        # Reply engagement bonus
        if reply_count > 10
          base_score += 0.1
        elsif reply_count > 5
          base_score += 0.05
        end
        
        # Solution marked bonus
        if item[:metadata]&.dig(:has_solution)
          base_score += 0.1
        end
        
        base_score
      end

      def calculate_stackoverflow_quality(question_score, answer_score, item)
        # StackOverflow specific quality calculation
        total_score = question_score + answer_score
        
        base_score = case total_score
                    when 0..10 then 0.6
                    when 11..50 then 0.7
                    when 51..100 then 0.8
                    when 101..500 then 0.9
                    else 0.95
                    end
        
        # Bonus for accepted answers
        base_score += 0.05 if item[:metadata]&.dig(:answer_id)
        
        base_score
      end

      def calculate_reddit_quality(item)
        upvote_ratio = item[:metadata]&.dig(:upvote_ratio) || 0.5
        score = item[:score] || 0
        num_comments = item[:metadata]&.dig(:num_comments) || 0
        
        # Base score from upvotes
        base_score = case score
                    when 0..5 then 0.5
                    when 6..20 then 0.6
                    when 21..50 then 0.7
                    when 51..100 then 0.8
                    else 0.9
                    end
        
        # Adjust by upvote ratio
        base_score *= upvote_ratio
        
        # Bonus for engagement
        base_score += 0.05 if num_comments > 10
        
        base_score
      end

      def calculate_confidence_score(question_score, answer_score)
        # Generic confidence calculation (from pipedata)
        total_score = question_score + answer_score
        
        case total_score
        when 0..10 then 0.6
        when 11..50 then 0.7
        when 51..100 then 0.8
        when 101..500 then 0.9
        else 0.95
        end
      end

      def save_to_file(items, file_path)
        # In production, actually write to file
        Rails.logger.info "Would save #{items.size} items to #{file_path}"
      end
    end
  end
end
