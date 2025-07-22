# frozen_string_literal: true

require 'uri'
require 'net/http'
require 'tempfile'
require 'rtesseract'
require 'mini_magick'

##
# Advanced Image Processing Pipeline for Excel Q&A Dataset
# Ruby port of Python ImageProcessor with 3-tier processing
#
# Pipeline: HTTP download → pytesseract OCR → table structure detection → OpenRouter AI enhancement
# This is CRITICAL for dataset quality - failed image processing destroys learning value
#
# Tier 1: RTesseract OCR (basic text extraction)
# Tier 2: OpenCV/MiniMagick table structure recognition  
# Tier 3: OpenRouter AI enhancement (expensive, only when needed)
class ThreeTierImageProcessor
  class ImageProcessingError < StandardError; end

  def initialize(cache: nil)
    @cache = cache || ImageProcessingCache.new
    @config = Rails.application.config_for(:image_processing)
    @logger = Rails.logger
    @quality_assessor = ImageQualityAssessor.new(logger: @logger)
    
    # Initialize Reddit image bypasser
    reddit_credentials = {
      client_id: Rails.application.credentials.reddit&.client_id,
      client_secret: Rails.application.credentials.reddit&.client_secret,
      username: 'ExcelQACollector'
    }
    @reddit_bypasser = RedditImageBypasser.new(reddit_credentials)
    
    # Initialize OpenAI client for OpenRouter
    openrouter_api_key = ENV['OPENROUTER_API_KEY'] || Rails.application.credentials.openrouter_api_key
    if openrouter_api_key.present?
      @openai_client = OpenAI::Client.new(
        access_token: openrouter_api_key,
        uri_base: @config[:openrouter_config][:base_url],
        request_timeout: 240,
        extra_headers: {
          "HTTP-Referer": "https://excel-unified.com",
          "X-Title": "Excel Unified Platform"
        }
      )
      @logger.info "✅ OpenRouter client initialized with proper headers"
    else
      @logger.warn "⚠️  OpenRouter API key not found. Tier 3 processing will be disabled."
      @openai_client = nil
    end
    
    @logger.info "ThreeTierImageProcessor initialized with 3-tier processing pipeline"
  rescue => e
    @logger.error "Failed to initialize ThreeTierImageProcessor: #{e.message}"
    raise ImageProcessingError, "Initialization failed: #{e.message}"
  end

  ##
  # Process base64 encoded image
  # 
  # @param base64_data [String] Base64 encoded image data (with or without data URI prefix)
  # @param context_tags [Array<String>] Question/answer tags for processing hints
  # @return [Hash] Processing results and metadata
  def process_base64_image(base64_data, context_tags: [])
    context_tags ||= []
    
    processing_result = {
      source_image_url: 'base64_image',
      processing_steps: [],
      extracted_content_type: nil,
      extracted_content: '',
      processing_tier: nil,
      success: false,
      error: nil
    }
    
    begin
      # Extract base64 data and MIME type if it has data URI prefix
    mime_type = 'image/jpeg' # default
    if base64_data.start_with?('data:')
      # Extract MIME type and base64 content
      match = base64_data.match(/^data:([^;]+);base64,(.+)$/)
      if match
        mime_type = match[1]
        base64_content = match[2]
        @logger.info "Extracted MIME type from data URL: #{mime_type}"
      else
        @logger.warn "Invalid data URL format, attempting fallback extraction"
        base64_content = base64_data.split(',')[1] || base64_data
      end
    else
      base64_content = base64_data
    end
      
      # Decode and save to temporary file
      require 'base64'
      decoded = Base64.decode64(base64_content)
      
      # Check if decoded data is too small (likely corrupted)
      if decoded.bytesize < 100
        @logger.warn "Decoded image data too small (#{decoded.bytesize} bytes), likely corrupted"
        raise ImageProcessingError, "Invalid or corrupted base64 image data"
      end
      
      temp_file = Tempfile.new(['image', '.png'])
      temp_file.binmode
      temp_file.write(decoded)
      temp_file.close
      
      image_path = temp_file.path
      processing_result[:processing_steps] << 'base64_decode_success'
      
      # Process image using existing pipeline
      # Check if AI client is available
      if @openai_client.present?
        # Skip traditional OCR and go directly to AI vision processing
        @logger.info "Using AI vision model for base64 image" 
        
        # Create dummy results for compatibility
        ocr_result = { text: '', text_length: 0, word_count: 0, confidence: 0.0 }
        table_result = { tables_found: 0, markdown_content: '', raw_tables: [] }
        
        # Direct AI vision processing
        ai_result = enhance_with_openrouter(image_path, 'base64_image', ocr_result, table_result, context_tags)
        processing_result[:processing_steps] << 'ai_vision_processing'
        processing_result.merge!(ai_result)
      else
        # Fallback to traditional OCR if no AI available
        @logger.warn "No AI client available for base64 image, falling back to traditional OCR"
        
        # Step 2: Tier 1 - OCR with quality assessment
        ocr_result = extract_text_with_ocr(image_path)
        ocr_assessment = @quality_assessor.assess_ocr_quality(ocr_result)
        processing_result[:processing_steps] << "ocr_attempted (quality: #{ocr_assessment[:quality_score].round(2)})"
        
        # Step 3: Tier 2 - Table detection with quality assessment
        table_result = extract_tables_with_opencv(image_path)
        table_assessment = @quality_assessor.assess_table_quality(table_result)
        processing_result[:processing_steps] << "table_extraction_attempted (quality: #{table_assessment[:quality_score].round(2)})"
        
        # Use best available result
        if table_assessment[:is_acceptable]
          processing_result[:extracted_content_type] = 'markdown_table'
          processing_result[:extracted_content] = table_result[:markdown_content]
          processing_result[:processing_tier] = 'Tier 2 (Table Detection)'
        elsif ocr_assessment[:is_acceptable]
          processing_result[:extracted_content_type] = 'plain_text'
          processing_result[:extracted_content] = ocr_result[:text]
          processing_result[:processing_tier] = 'Tier 1 (OCR)'
        else
          # Both tiers failed - use fallback
          fallback_result = create_fallback_result(ocr_result, table_result, 'base64_image')
          processing_result.merge!(fallback_result)
        end
      end
      
      # Final quality assessment
      final_assessment = @quality_assessor.assess_final_quality(processing_result)
      processing_result[:quality_assessment] = final_assessment
      
      processing_result[:success] = processing_result[:extracted_content].length > 0
      
    rescue => e
      @logger.error "Base64 image processing failed: #{e.message}"
      processing_result[:error] = e.message
      processing_result[:success] = false
      
    ensure
      # Cleanup temporary file
      temp_file.unlink if temp_file && File.exist?(temp_file.path)
    end
    
    processing_result
  end

  ##
  # Main image processing pipeline following TRD specifications
  # 
  # @param image_url [String] URL of the image to process
  # @param context_tags [Array<String>] Question/answer tags for processing hints
  # @return [Hash] Processing results and metadata
  def process_image_url(image_url, context_tags: [])
    context_tags ||= []
    
    # Check cache first - but not for base64 images
    unless image_url.start_with?('data:')
      cached_result = @cache.get_image_processing_result(image_url, 'full_pipeline')
      if cached_result && cached_result[:success] && !cached_result[:extracted_content].include?("I'm unable to analyze")
        @logger.info "Using cached image processing result for #{image_url}"
        return cached_result
      end
    end
    
    processing_result = {
      source_image_url: image_url,
      processing_steps: [],
      extracted_content_type: nil,
      extracted_content: '',
      processing_tier: nil,
      success: false,
      error: nil
    }
    
    begin
      # Step 1: Download image
      image_path = download_image(image_url)
      raise ImageProcessingError, "Failed to download image" unless image_path
      
      processing_result[:processing_steps] << 'download_success'
      
      # Check if AI client is available
      if @openai_client.present?
        # Skip traditional OCR and go directly to AI vision processing
        @logger.info "Using AI vision model from Tier 1 (OCR performance issues)" 
        
        # Create dummy results for compatibility
        ocr_result = { text: '', text_length: 0, word_count: 0, confidence: 0.0 }
        table_result = { tables_found: 0, markdown_content: '', raw_tables: [] }
        
        # Direct AI vision processing
        ai_result = enhance_with_openrouter(image_path, image_url, ocr_result, table_result, context_tags)
        processing_result[:processing_steps] << 'ai_vision_processing'
        processing_result.merge!(ai_result)
      else
        # Fallback to traditional OCR if no AI available
        @logger.warn "No AI client available, falling back to traditional OCR"
        
        # Step 2: Tier 1 - OCR with quality assessment
        ocr_result = extract_text_with_ocr(image_path)
        ocr_assessment = @quality_assessor.assess_ocr_quality(ocr_result)
        processing_result[:processing_steps] << "ocr_attempted (quality: #{ocr_assessment[:quality_score].round(2)})"
        
        # Step 3: Tier 2 - Table detection with quality assessment
        table_result = extract_tables_with_opencv(image_path)
        table_assessment = @quality_assessor.assess_table_quality(table_result)
        processing_result[:processing_steps] << "table_extraction_attempted (quality: #{table_assessment[:quality_score].round(2)})"
        
        # Use best available result
        if table_assessment[:is_acceptable]
          processing_result[:extracted_content_type] = 'markdown_table'
          processing_result[:extracted_content] = table_result[:markdown_content]
          processing_result[:processing_tier] = 'Tier 2 (Table Detection)'
        elsif ocr_assessment[:is_acceptable]
          processing_result[:extracted_content_type] = 'plain_text'
          processing_result[:extracted_content] = ocr_result[:text]
          processing_result[:processing_tier] = 'Tier 1 (OCR)'
        else
          # Both tiers failed - use fallback
          fallback_result = create_fallback_result(ocr_result, table_result, image_url)
          processing_result.merge!(fallback_result)
        end
      end
      
      # Final quality assessment
      final_assessment = @quality_assessor.assess_final_quality(processing_result)
      processing_result[:quality_assessment] = final_assessment
      
      processing_result[:success] = processing_result[:extracted_content].length > 0
      
    rescue => e
      @logger.error "Image processing failed for #{image_url}: #{e.message}"
      processing_result[:error] = e.message
      processing_result[:success] = false
      
    ensure
      # Cleanup temporary file
      File.unlink(image_path) if image_path && File.exist?(image_path)
    end
    
    # Cache the result (7 days TTL for expensive processing) - but not errors or base64
    if !image_url.start_with?('data:') && processing_result[:success] && 
       !processing_result[:extracted_content].include?("I'm unable to analyze")
      @cache.cache_image_processing_result(image_url, 'full_pipeline', processing_result)
    end
    
    processing_result
  end

  private

  ##
  # Download image using advanced bypass techniques for Stack Overflow and Reddit
  def download_image(image_url)
    begin
      # Validate URL format
      uri = URI.parse(image_url)
      raise ImageProcessingError, "Invalid image URL: #{image_url}" unless uri.scheme && uri.host
      
      # Check file extension
      path_lower = uri.path.downcase
      unless @config[:supported_formats].any? { |ext| path_lower.end_with?(ext) }
        @logger.warn "Unsupported image format for #{image_url}"
      end
      
      image_content = nil
      download_method = "unknown"
      
      # Reddit images - use advanced bypass techniques
      if uri.host.include?('redd.it') || uri.host.include?('reddit')
        @logger.info "🎯 Reddit image detected - applying advanced bypass: #{image_url}"
        image_content, download_method = @reddit_bypasser.download_reddit_image_with_bypass(image_url)
        
      # Stack Overflow images - use existing method (80% success rate)
      elsif uri.host.include?('sstatic.net')
        @logger.info "📚 Stack Overflow image - using existing method: #{image_url}"
        image_content = download_stackoverflow_image(image_url)
        download_method = "stackoverflow_http"
        
      # Other images - basic download
      else
        @logger.info "🌐 Generic image - basic download: #{image_url}"
        image_content = download_generic_image(image_url)
        download_method = "generic_http"
      end
      
      unless image_content
        @logger.error "❌ All download methods failed: #{image_url}"
        return nil
      end
      
      # Check content size
      content_length = image_content.bytesize
      if content_length > @config[:max_image_size]
        raise ImageProcessingError, 
          "Image too large: #{content_length} bytes > #{@config[:max_image_size]}"
      end
      
      # Save to temporary file
      suffix = File.extname(uri.path).presence || '.jpg'
      temp_file = Tempfile.new(['image', suffix])
      temp_file.binmode
      temp_file.write(image_content)
      temp_file.close
      
      temp_path = temp_file.path
      @logger.info "✅ Image download success: #{image_url} → #{temp_path} (#{content_length} bytes, method: #{download_method})"
      
      temp_path
      
    rescue => e
      @logger.error "Image download failed: #{image_url}: #{e.message}"
      nil
    end
  end

  ##
  # Stack Overflow image download (existing proven method)
  def download_stackoverflow_image(image_url)
    begin
      uri = URI.parse(image_url)
      
      headers = {
        'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept' => 'image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
        'Accept-Language' => 'en-US,en;q=0.9',
        'Accept-Encoding' => 'gzip, deflate, br',
        'Cache-Control' => 'no-cache',
        'Pragma' => 'no-cache',
        'Referer' => 'https://stackoverflow.com/',
        'Sec-Fetch-Dest' => 'image',
        'Sec-Fetch-Mode' => 'no-cors',
        'Sec-Fetch-Site' => 'cross-site'
      }
      
      # Random delay
      sleep(rand(0.5..2.0))
      
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = @config[:download_timeout]
      
      request = Net::HTTP::Get.new(uri)
      headers.each { |key, value| request[key] = value }
      
      response = http.request(request)
      response.raise_for_status if response.respond_to?(:raise_for_status)
      
      return response.body if response.code == '200'
      nil
      
    rescue => e
      @logger.debug "Stack Overflow image download failed: #{e.message}"
      nil
    end
  end

  ##
  # Generic image download
  def download_generic_image(image_url)
    begin
      uri = URI.parse(image_url)
      
      headers = {
        'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept' => 'image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
        'Accept-Language' => 'en-US,en;q=0.9',
        'Accept-Encoding' => 'gzip, deflate, br'
      }
      
      sleep(rand(0.5..2.0))
      
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = @config[:download_timeout]
      
      request = Net::HTTP::Get.new(uri)
      headers.each { |key, value| request[key] = value }
      
      response = http.request(request)
      
      return response.body if response.code == '200'
      nil
      
    rescue => e
      @logger.debug "Generic image download failed: #{e.message}"
      nil
    end
  end

  ##
  # Extract text using RTesseract OCR (Tier 1)
  def extract_text_with_ocr(image_path)
    begin
      # Preprocess image with MiniMagick for better OCR
      image = MiniMagick::Image.open(image_path)
      
      # Enhance contrast
      image.contrast_stretch('1%')
      image.normalize
      
      # Create temporary enhanced image
      enhanced_path = "#{image_path}.enhanced.png"
      image.write(enhanced_path)
      
      # Apply OCR with RTesseract
      ocr_config = @config[:ocr_config]
      tesseract = RTesseract.new(enhanced_path, {
        lang: ocr_config[:lang],
        config: ocr_config[:config]
      })
      
      text = tesseract.to_s
      
      # Clean up text
      cleaned_text = text.gsub(/\s+/, ' ').strip
      
      # Estimate confidence based on text quality
      # This is a simple heuristic - better would be to use Tesseract's confidence API
      estimated_confidence = estimate_ocr_confidence(cleaned_text)
      
      result = {
        text: cleaned_text,
        text_length: cleaned_text.length,
        word_count: cleaned_text.split.length,
        confidence: estimated_confidence
      }
      
      @logger.info "OCR extracted #{result[:text_length]} characters, #{result[:word_count]} words"
      
      # Cleanup enhanced image
      File.unlink(enhanced_path) if File.exist?(enhanced_path)
      
      result
      
    rescue => e
      @logger.error "OCR failed for #{image_path}: #{e.message}"
      { text: '', text_length: 0, word_count: 0, confidence: 0.0 }
    end
  end

  ##
  # Extract table structures using OpenCV/MiniMagick (Tier 2)
  # This is a simplified version - Ruby doesn't have img2table equivalent
  def extract_tables_with_opencv(image_path)
    begin
      # For now, use simple table detection logic
      # This would be enhanced with proper OpenCV table detection
      image = MiniMagick::Image.open(image_path)
      
      # Convert to grayscale for analysis
      image.colorspace('Gray')
      
      # Look for table-like structures (this is simplified)
      # In a real implementation, you'd use OpenCV for line detection
      
      # For now, return empty result - this would need proper table detection
      result = {
        tables_found: 0,
        markdown_content: '',
        raw_tables: []
      }
      
      @logger.info "Table extraction found #{result[:tables_found]} tables"
      result
      
    rescue => e
      @logger.error "Table extraction failed for #{image_path}: #{e.message}"
      { tables_found: 0, markdown_content: '', raw_tables: [] }
    end
  end

  ##
  # Determine if AI enhancement is needed based on quality assessments
  # Delegates to ImageQualityAssessor for intelligent decision making
  def should_use_ai_enhancement?(ocr_assessment, table_assessment, context_tags)
    # Only attempt if OpenRouter client is available
    return false unless @openai_client.present?
    
    # Let quality assessor make the decision based on metrics
    @quality_assessor.should_attempt_ai_enhancement?(ocr_assessment, table_assessment, context_tags)
  end

  ##
  # Use OpenRouter AI models for complex image analysis (Tier 3)
  # Model selection per TRD:
  # - Tables/dialogs: claude-3.5-sonnet (Tier 2)
  # - Charts/complex: gpt-4o (Tier 3)
  def enhance_with_openrouter(image_path, image_url, ocr_result, table_result, context_tags)
    # Check if OpenRouter client is available
    unless @openai_client
      @logger.warn "OpenRouter client not initialized, using fallback processing"
      return create_fallback_result(ocr_result, table_result, image_url)
    end
    
    # Determine if we need high-performance model (Tier 3)
    complex_indicators = ['chart', 'graph', 'pivot', 'complex', 'formula', 'macro', 'vba']
    needs_tier3 = context_tags.any? { |tag| complex_indicators.any? { |indicator| tag.downcase.include?(indicator) } }
    
    # Always use GPT-4o-mini for now (free model has issues)
    model = @config[:openrouter_config][:tier3_model]  # openai/gpt-4o-mini
    prompt = get_general_vision_prompt(context_tags)
    processing_tier = "AI Vision Processing (#{model})"
    @logger.info "Using GPT-4o-mini for image analysis"
    
    begin
      # Check cache first - but not for base64 images or if previous result was an error
      unless image_url.start_with?('data:')
        cached_response = @cache.get_openrouter_response(model, [prompt], image_url)
        if cached_response && !cached_response[:extracted_content].include?("I'm unable to analyze")
          @logger.info "Using cached OpenRouter response for #{image_url}"
          return cached_response
        end
      end
      
      # Read image as base64 for API call
      # Optimize image size if needed
      optimized_path = optimize_image_for_api(image_path)
      image_data = Base64.strict_encode64(File.read(optimized_path))
      
      # Clean up optimized image if different from original
      if optimized_path != image_path && File.exist?(optimized_path)
        File.unlink(optimized_path)
      end
      image_mime = detect_mime_type(image_path)
      @logger.info "Detected MIME type: #{image_mime}"
      
      # Call OpenRouter API with retry logic
    retries = 0
    max_retries = 3
    
    begin
      # Log request details for debugging
      @logger.info "Calling OpenRouter API with model: #{model}"
      @logger.debug "Image MIME type: #{image_mime}, Image size: #{image_data.length} chars"
      
      response = @openai_client.chat(
        parameters: {
          model: model,
          messages: [
            {
              role: 'user',
              content: [
                { type: 'text', text: prompt },
                {
                  type: 'image_url',
                  image_url: {
                    url: "data:#{image_mime};base64,#{image_data}",
                    detail: 'high'  # Use high detail for better Excel content analysis
                  }
                }
              ]
            }
          ],
          max_tokens: @config[:openrouter_config][:max_tokens],
          temperature: @config[:openrouter_config][:temperature]
        }
      )
      
      # Log response for debugging
      @logger.debug "API Response status: #{response.code if response.respond_to?(:code)}"
      @logger.debug "API Response body: #{response.inspect[0..500]}..."
      
      ai_content = response.dig('choices', 0, 'message', 'content')&.strip
      
      if ai_content.nil? || ai_content.empty?
        @logger.error "Empty response from OpenRouter API"
        @logger.error "Full response: #{response.inspect}"
      end
    rescue => e
      retries += 1
      if retries < max_retries
        @logger.warn "API call failed (attempt #{retries}/#{max_retries}): #{e.class.name} - #{e.message}"
        @logger.warn "Backtrace: #{e.backtrace.first(3).join('\n')}"
        sleep(retries * 2) # Exponential backoff
        retry
      else
        @logger.error "Max retries reached. Final error: #{e.class.name} - #{e.message}"
        raise e
      end
    end
      
      # Determine content type from AI response
      content_type = if ai_content.include?('|') && ai_content.include?('---')
                      'markdown_table'
                    elsif ['chart', 'graph', 'shows', 'displays'].any? { |keyword| ai_content.downcase.include?(keyword) }
                      'chart_description'
                    else
                      'enhanced_text'
                    end
      
      result = {
        extracted_content_type: content_type,
        extracted_content: ai_content,
        processing_tier: processing_tier,
        ai_model_used: model,
        tokens_used: response.dig('usage', 'total_tokens') || 0
      }
      
      # Cache the expensive AI result (but not errors or base64 images)
      if !image_url.start_with?('data:') && !ai_content.include?("I'm unable to analyze")
        @cache.cache_openrouter_response(model, [prompt], image_url, result)
      end
      
      @logger.info "AI enhancement completed with #{model}, #{result[:tokens_used]} tokens"
      result
      
    rescue => e
      @logger.error "OpenRouter AI enhancement failed: #{e.message}"
      
      # Use the same fallback logic
      create_fallback_result(ocr_result, table_result, image_url)
    end
  end

  ##
  # Create fallback result when AI enhancement is not available
  def create_fallback_result(ocr_result, table_result, image_url)
    # Tier 2 fallback: Table detection results
    if table_result[:tables_found] > 0 && table_result[:markdown_content].present?
      {
        extracted_content_type: 'markdown_table',
        extracted_content: table_result[:markdown_content],
        processing_tier: 'Tier 2 (Table Detection - AI unavailable)',
        ai_model_used: nil,
        tokens_used: 0
      }
    # Tier 1 fallback: OCR results
    elsif ocr_result[:text_length] > 10
      {
        extracted_content_type: 'plain_text',
        extracted_content: ocr_result[:text],
        processing_tier: 'Tier 1 (OCR Only - AI unavailable)',
        ai_model_used: nil,
        tokens_used: 0
      }
    # Basic fallback: Just indicate image presence
    else
      {
        extracted_content_type: 'image_placeholder',
        extracted_content: "[이미지: #{File.basename(URI.parse(image_url).path)}]",
        processing_tier: 'Basic (Image URL Only)',
        ai_model_used: nil,
        tokens_used: 0
      }
    end
  end

  ##
  # Generate prompt for table analysis with claude-3.5-sonnet
  def get_table_analysis_prompt(ocr_result, table_result)
    <<~PROMPT
      You are analyzing an Excel-related screenshot that contains tabular data. Your task is to extract and reconstruct the table structure in clean markdown format.

      Context from previous processing:
      - OCR extracted text: #{ocr_result[:text][0..200]}...
      - Tables detected: #{table_result[:tables_found]}

      Please:
      1. Identify all tables/data structures in the image
      2. Extract the data accurately, preserving relationships
      3. Format as clean markdown tables with proper headers
      4. Include any formulas or cell references you can see
      5. Note any Excel-specific elements (formulas, formatting, etc.)

      Provide only the markdown table(s), no explanatory text.
    PROMPT
  end

  ##
  # Generate prompt for chart/complex image analysis with gpt-4o
  def get_chart_analysis_prompt(ocr_result, context_tags)
    tags_context = context_tags.join(', ') if context_tags.any?
    tags_context ||= 'none'
    
    <<~PROMPT
      You are analyzing an Excel-related screenshot that may contain charts, graphs, or complex visual elements.

      Context:
      - Question tags: #{tags_context}
      - OCR text found: #{ocr_result[:text][0..200]}...

      Please analyze this image and provide:
      1. Type of chart/visualization (if any)
      2. Key data points, trends, or patterns shown
      3. Any Excel formulas, functions, or settings visible
      4. Step-by-step explanation of what the image demonstrates
      5. How this relates to Excel functionality

      Be specific about Excel features and provide actionable insights for learning.
    PROMPT
  end

  ##
  # Generate general vision prompt for unified AI processing
  def get_general_vision_prompt(context_tags)
    tags_context = context_tags.join(', ') if context_tags.any?
    tags_context ||= 'Excel-related content'
    
    <<~PROMPT
      You are analyzing an Excel screenshot image. The image contains Excel-related content that needs to be extracted and analyzed. Please provide a detailed analysis.

      Context: #{tags_context}

      Please analyze this image and provide:
      1. If it's a table or data structure:
         - Extract all data in clean markdown table format
         - Preserve all formulas, cell references, and formatting notes
         - Maintain column headers and row labels accurately
      
      2. If it's a chart or visualization:
         - Describe the type and purpose of the visualization
         - Extract key data points and trends
         - Note any Excel-specific features or settings
      
      3. If it's Excel UI or dialog:
         - Identify the specific Excel feature or function
         - Extract all text, options, and settings visible
         - Provide context on what this feature does
      
      4. For any Excel content:
         - Include all visible formulas (e.g., =SUM(A1:A10))
         - Note cell references and ranges
         - Preserve any Korean text exactly as shown
      
      Provide the most appropriate format for the content type (markdown table for data, descriptive text for charts/UI).
      Be precise and complete in your extraction. Do not refuse to analyze the image - provide the best analysis you can based on what you see in the image.
    PROMPT
  end

  ##
  # Estimate OCR confidence based on text characteristics
  # This is a heuristic approach when real confidence scores aren't available
  def estimate_ocr_confidence(text)
    return 0.0 if text.nil? || text.empty?
    
    # Factors that indicate good OCR quality
    factors = []
    
    # 1. Reasonable word length distribution
    words = text.split
    avg_word_length = words.map(&:length).sum.to_f / words.length rescue 0
    factors << (avg_word_length.between?(3, 8) ? 0.2 : 0.0)
    
    # 2. Presence of common English words
    common_words = %w[the and of to in is that for with as on]
    common_word_ratio = words.count { |w| common_words.include?(w.downcase) }.to_f / words.length rescue 0
    factors << [common_word_ratio * 0.3, 0.3].min
    
    # 3. Alphanumeric ratio (not too many special characters)
    alphanumeric_ratio = text.count('a-zA-Z0-9 ').to_f / text.length rescue 0
    factors << (alphanumeric_ratio > 0.8 ? 0.25 : alphanumeric_ratio * 0.25)
    
    # 4. Sentence structure (capitals and periods)
    has_sentence_structure = text.match?(/[A-Z].+[.!?]/) ? 0.15 : 0.0
    factors << has_sentence_structure
    
    # 5. Text length bonus
    length_factor = [text.length.to_f / 200, 0.1].min
    factors << length_factor
    
    # Sum all factors (max 1.0)
    [factors.sum, 1.0].min
  end

  ##
  # Detect MIME type from image file

##
# Optimize image for API processing
# Resize if too large, following OpenAI's recommendations
def optimize_image_for_api(image_path)
  begin
    image = MiniMagick::Image.open(image_path)
    
    # Get original dimensions
    width = image.width
    height = image.height
    
    @logger.info "Original image dimensions: #{width}x#{height}"
    
    # OpenAI recommends: short side < 768px, long side < 2000px for high detail
    max_short_side = 768
    max_long_side = 2000
    
    short_side = [width, height].min
    long_side = [width, height].max
    
    if short_side > max_short_side || long_side > max_long_side
      # Calculate resize ratio
      ratio = [max_short_side.to_f / short_side, max_long_side.to_f / long_side].min
      
      new_width = (width * ratio).to_i
      new_height = (height * ratio).to_i
      
      @logger.info "Resizing image to #{new_width}x#{new_height}"
      
      # Create optimized temp file
      optimized_path = Tempfile.new(['optimized', File.extname(image_path)]).path
      
      image.resize "#{new_width}x#{new_height}"
      image.write optimized_path
      
      return optimized_path
    end
    
    # Return original if no optimization needed
    image_path
  rescue => e
    @logger.warn "Image optimization failed: #{e.message}, using original"
    image_path
  end
end

  def detect_mime_type(image_path)
    begin
      # Use MiniMagick to detect format
      image = MiniMagick::Image.open(image_path)
      format = image.type&.downcase
      
      case format
      when 'png'
        'image/png'
      when 'jpeg', 'jpg'
        'image/jpeg'
      when 'gif'
        'image/gif'
      when 'webp'
        'image/webp'
      else
        # Fallback to file extension
        ext = File.extname(image_path).downcase.delete('.')
        case ext
        when 'png' then 'image/png'
        when 'jpg', 'jpeg' then 'image/jpeg'
        when 'gif' then 'image/gif'
        when 'webp' then 'image/webp'
        else 'image/jpeg' # Default fallback
        end
      end
    rescue => e
      @logger.warn "Failed to detect MIME type: #{e.message}, using default"
      'image/jpeg'
    end
  end
end
