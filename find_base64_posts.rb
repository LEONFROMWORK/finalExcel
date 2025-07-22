#!/usr/bin/env ruby
# Find posts with base64 images on Oppadu

require 'playwright'

puts "🔍 Finding Oppadu Posts with Base64 Images..."
puts "=" * 60

Playwright.create(playwright_cli_executable_path: './node_modules/.bin/playwright') do |playwright|
  playwright.chromium.launch(headless: false) do |browser|  # headless: false to see what's happening
    page = browser.new_page
    
    base64_posts = []
    max_pages = 10
    
    (1..max_pages).each do |page_num|
      url = page_num > 1 ? "https://www.oppadu.com/community/question/?pg=#{page_num}" : "https://www.oppadu.com/community/question/"
      
      puts "\nChecking page #{page_num}..."
      page.goto(url)
      page.wait_for_selector('.post-item-modern')
      
      # Get all posts with answers
      posts = page.query_selector_all('.post-item-modern')
      answered_count = 0
      
      posts.each_with_index do |post, idx|
        # Check for answer badge
        badge = post.query_selector('.answer-complete-badge')
        next unless badge
        
        answered_count += 1
        
        # Get link
        link = post.query_selector('a')
        next unless link
        
        title = link.text_content.strip
        href = link.get_attribute('href')
        post_url = href.start_with?('http') ? href : "https://www.oppadu.com#{href}"
        
        # Quick check if this might have images
        # Open in new page to check
        detail_page = browser.new_page
        begin
          detail_page.goto(post_url)
          detail_page.wait_for_selector('.post-content', timeout: 5000)
          
          # Check all images
          all_images = detail_page.query_selector_all('img')
          base64_images = []
          
          all_images.each do |img|
            src = img.get_attribute('src')
            if src && src.start_with?('data:image')
              base64_images << src[0..100] + "..."  # First 100 chars
            end
          end
          
          if base64_images.any?
            puts "\n✅ Found base64 images in: #{title}"
            puts "   URL: #{post_url}"
            puts "   Base64 images: #{base64_images.size}"
            
            base64_posts << {
              page: page_num,
              title: title,
              url: post_url,
              base64_count: base64_images.size
            }
            
            # Show first few characters of base64
            base64_images.first(2).each_with_index do |b64, i|
              puts "   Image #{i+1}: #{b64}"
            end
          end
          
        rescue => e
          puts "   Error checking #{title}: #{e.message}"
        ensure
          detail_page.close
        end
        
        # Stop if we found enough examples
        break if base64_posts.size >= 3
      end
      
      puts "Answered posts on page #{page_num}: #{answered_count}"
      
      # Stop if we found enough examples
      break if base64_posts.size >= 3
    end
    
    puts "\n" + "=" * 60
    puts "📊 Summary:"
    puts "Total base64 posts found: #{base64_posts.size}"
    
    if base64_posts.any?
      puts "\nBase64 posts:"
      base64_posts.each_with_index do |post, idx|
        puts "#{idx + 1}. Page #{post[:page]}: #{post[:title]}"
        puts "   #{post[:url]}"
      end
    else
      puts "No posts with base64 images found in #{max_pages} pages"
    end
  end
end

puts "\n✨ Search complete!"