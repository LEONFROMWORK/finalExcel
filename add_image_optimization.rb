#!/usr/bin/env ruby
# Add image optimization for better API compatibility

require_relative 'config/environment'

puts "🔧 Adding image optimization for better API compatibility..."
puts "=" * 60

file_path = Rails.root.join('app/services/three_tier_image_processor.rb')
content = File.read(file_path)

# Add image optimization method
unless content.include?("def optimize_image_for_api")
  # Find the last method definition
  insertion_point = content.rindex(/^\s*def\s+\w+/)
  
  if insertion_point
    # Insert before the detect_mime_type method
    method_def = <<~'RUBY'

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
RUBY

    # Insert the method
    new_content = content[0...insertion_point] + method_def + "\n" + content[insertion_point..-1]
    
    File.write(file_path, new_content)
    puts "✅ Added optimize_image_for_api method"
  end
end

# Update enhance_with_openrouter to use optimization
content = File.read(file_path)

if content.include?("# Read image as base64 for API call")
  updated_content = content.gsub(
    /# Read image as base64 for API call\s*\n\s*image_data = Base64\.strict_encode64\(File\.read\(image_path\)\)/,
    <<~'RUBY'.strip
# Read image as base64 for API call
      # Optimize image size if needed
      optimized_path = optimize_image_for_api(image_path)
      image_data = Base64.strict_encode64(File.read(optimized_path))
      
      # Clean up optimized image if different from original
      if optimized_path != image_path && File.exist?(optimized_path)
        File.unlink(optimized_path)
      end
RUBY
  )
  
  File.write(file_path, updated_content)
  puts "✅ Updated enhance_with_openrouter to use image optimization"
end

# Also add a check for very small base64 strings (might be corrupted)
content = File.read(file_path)

if content.include?("decoded = Base64.decode64(base64_content)")
  updated_content = content.gsub(
    /decoded = Base64\.decode64\(base64_content\)/,
    <<~'RUBY'.strip
decoded = Base64.decode64(base64_content)
      
      # Check if decoded data is too small (likely corrupted)
      if decoded.bytesize < 100
        @logger.warn "Decoded image data too small (#{decoded.bytesize} bytes), likely corrupted"
        raise ImageProcessingError, "Invalid or corrupted base64 image data"
      end
RUBY
  )
  
  File.write(file_path, updated_content)
  puts "✅ Added base64 validation"
end

puts "\n✅ All optimizations applied!"
puts "\nNext steps:"
puts "1. Test with Oppadu images again"
puts "2. Monitor for improvements in image analysis"