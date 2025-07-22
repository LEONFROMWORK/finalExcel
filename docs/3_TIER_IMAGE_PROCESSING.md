# 3-Tier Image Processing System

This document describes the Ruby implementation of pipedata's 3-tier image processing system, ported from Python to Rails.

## Overview

The 3-tier image processing system processes Excel-related images with increasing levels of sophistication:

- **Tier 1**: RTesseract OCR (basic text extraction)
- **Tier 2**: OpenCV/MiniMagick table structure recognition
- **Tier 3**: OpenRouter AI enhancement (expensive, only when needed)

## Architecture

### Core Components

1. **ThreeTierImageProcessor** - Main processing engine
2. **ImageProcessingCache** - Caching layer for expensive operations
3. **RedditImageBypasser** - Specialized Reddit image downloading
4. **ProcessImageJob** - Background processing job
5. **ImageContentProcessor** - Enhanced legacy processor

### Processing Flow

```
Image URL → Download → OCR (Tier 1) → Table Detection (Tier 2) → AI Enhancement (Tier 3) → Result
                ↓
            Cache Check
```

## Configuration

### Configuration File: `config/image_processing.yml`

```yaml
default: &default
  supported_formats: ['.jpg', '.jpeg', '.png', '.gif', '.webp']
  download_timeout: 30
  max_image_size: 10485760  # 10MB
  
  ocr_config:
    lang: 'eng'
    config: '--psm 6'
  
  openrouter_config:
    base_url: 'https://openrouter.ai/api/v1'
    tier2_model: 'anthropic/claude-3.5-sonnet'
    tier3_model: 'openai/gpt-4o'
    max_tokens: 4000
    temperature: 0.1
```

### Required Credentials

Add to `config/credentials.yml.enc`:

```yaml
openrouter_api_key: your_openrouter_api_key

reddit:
  client_id: your_reddit_client_id
  client_secret: your_reddit_client_secret
```

### Required Gems

Add to `Gemfile`:

```ruby
gem "ruby-opencv", "~> 0.0.18"  # Image processing
gem "rtesseract", "~> 3.1"      # OCR
gem "openai", "~> 0.3.0"        # AI integration
```

## Usage

### Basic Processing

```ruby
# Initialize processor
processor = ThreeTierImageProcessor.new

# Process single image
result = processor.process_image_url(
  'https://example.com/image.png',
  context_tags: ['chart', 'excel', 'formula']
)

# Check result
if result[:success]
  puts "Tier: #{result[:processing_tier]}"
  puts "Content: #{result[:extracted_content]}"
end
```

### Enhanced Content Processing

```ruby
# Use enhanced ImageContentProcessor
processed_content = ImageContentProcessor.process_images_in_content(
  original_content,
  images,
  use_advanced_processing: true,
  context_tags: ['excel', 'table']
)
```

### Background Processing

```ruby
# Process single image in background
ProcessImageJob.perform_later(
  image_url,
  context_tags: ['chart'],
  callback_class: 'MyProcessor',
  callback_method: 'handle_result'
)

# Batch processing
ProcessImageJob.process_batch(
  image_urls,
  context_tags: ['excel'],
  batch_callback_class: 'BatchProcessor',
  batch_callback_method: 'handle_batch_results'
)
```

## Tier Decision Logic

The system automatically decides which tier to use based on:

1. **OCR Success**: If OCR extracts > 20 chars and > 5 words → Tier 1 sufficient
2. **Table Detection**: If tables found → Tier 2 sufficient
3. **Chart Keywords**: If context contains chart/graph keywords → Tier 3 needed
4. **Poor Results**: If Tiers 1-2 fail → Tier 3 enhancement

## Reddit Image Handling

The `RedditImageBypasser` provides sophisticated techniques to bypass 403 errors:

### Methods Used

1. **Basic HTTP**: Standard headers and user agents
2. **OAuth HTTP**: Uses Reddit API credentials
3. **Session Spoofing**: Fake cookies and session data
4. **Proxy Simulation**: X-Forwarded headers

### URL Alternatives

- `preview.redd.it` → `i.redd.it`
- Various quality parameters
- HTTPS → HTTP fallback

## Caching Strategy

### Cache Keys

- **Image Processing**: `img_proc:{hash}`
- **OpenRouter Responses**: `openrouter:{hash}`
- **Stack Overflow API**: `so_api:{hash}`

### TTL Values

- **Image Processing**: 7 days (expensive)
- **OpenRouter AI**: 7 days (very expensive)
- **API Responses**: 24 hours (standard)

## Error Handling

### Automatic Retries

- Network errors: 3 attempts with exponential backoff
- Temporary failures: Automatic retry
- Permanent failures: Immediate discard

### Fallback Strategy

```
Tier 3 AI fails → Tier 2 tables → Tier 1 OCR → Basic description
```

### Error Types

- `ImageProcessingError`: Processing failures
- `RedditBypassError`: Reddit-specific errors
- Network timeouts, invalid URLs, etc.

## Performance Considerations

### Optimization Features

- **Aggressive Caching**: Avoid reprocessing
- **Smart Tier Selection**: Skip expensive tiers when possible
- **Background Processing**: Non-blocking operations
- **Batch Operations**: Efficient bulk processing

### Resource Usage

- **Memory**: Images processed in temporary files
- **Network**: Respectful delays between requests
- **API Costs**: Minimal AI usage through smart decisions

## Monitoring and Logging

### Log Levels

- **Info**: Processing start/completion
- **Debug**: Detailed processing steps
- **Warn**: Non-critical failures
- **Error**: Processing failures

### Metrics Tracked

- Processing success rates
- Tier usage distribution
- Cache hit rates
- Processing times
- API token usage

## Examples

### Processing Excel Screenshots

```ruby
# Table screenshot
result = processor.process_image_url(
  'https://i.stack.imgur.com/table.png',
  context_tags: ['excel', 'table', 'vlookup']
)
# → Uses Tier 2 (claude-3.5-sonnet) for table analysis

# Chart screenshot  
result = processor.process_image_url(
  'https://preview.redd.it/chart.png', 
  context_tags: ['excel', 'chart', 'pivot']
)
# → Uses Tier 3 (gpt-4o) for chart analysis

# Simple formula screenshot
result = processor.process_image_url(
  'https://example.com/formula.png',
  context_tags: ['excel', 'formula']
)
# → Uses Tier 1 (OCR) if text is clear
```

### Integration with Existing Systems

```ruby
# In data collection services
class PlatformDataCollector
  def process_collected_images(images, context_tags)
    images.each do |image|
      ProcessImageJob.perform_later(
        image[:url],
        context_tags: context_tags,
        callback_class: 'DataCollector',
        callback_method: 'store_processed_result'
      )
    end
  end
end
```

## Troubleshooting

### Common Issues

1. **OCR Not Working**: Install Tesseract system dependencies
2. **OpenCV Issues**: Install OpenCV development libraries
3. **Reddit 403s**: Check Reddit API credentials
4. **AI Failures**: Verify OpenRouter API key and credits

### Debug Mode

```ruby
# Enable detailed logging
Rails.logger.level = :debug

# Test individual components
bypasser = RedditImageBypasser.new(credentials)
result, method = bypasser.download_reddit_image_with_bypass(url)
puts "Success: #{result ? 'Yes' : 'No'}, Method: #{method}"
```

## Migration from Python

The Ruby implementation maintains full compatibility with the Python system:

- **Same tier logic**: Identical decision making
- **Same prompts**: Identical AI prompts
- **Same caching**: Compatible cache keys
- **Same results**: Equivalent output format

### Key Differences

- **RTesseract vs pytesseract**: Ruby OCR wrapper
- **MiniMagick vs PIL**: Ruby image processing
- **Net::HTTP vs httpx**: Ruby HTTP client
- **Rails.cache vs SQLite**: Rails caching system

## Future Enhancements

1. **Advanced Table Detection**: Implement proper OpenCV table recognition
2. **Model Selection**: Dynamic model selection based on image type
3. **Performance Metrics**: Enhanced monitoring and analytics
4. **Custom Models**: Support for fine-tuned Excel-specific models
5. **Parallel Processing**: Multi-threaded image processing

## Support

For issues or questions about the 3-tier image processing system:

1. Check logs for detailed error information
2. Verify all dependencies are installed
3. Test individual components in isolation
4. Review configuration and credentials