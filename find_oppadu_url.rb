#!/usr/bin/env ruby
# Find correct Oppadu URL

require 'selenium-webdriver'

puts "Finding correct Oppadu URL..."
puts "=" * 60

options = Selenium::WebDriver::Chrome::Options.new
options.add_argument('--headless=new')
options.add_argument('--no-sandbox')
options.add_argument('--disable-dev-shm-usage')

driver = Selenium::WebDriver.for(:chrome, options: options)

begin
  # Test different URLs
  urls = [
    'https://www.oppadu.com',
    'https://www.oppadu.com/community',
    'https://www.oppadu.com/board',
    'https://www.oppadu.com/qna',
    'https://www.oppadu.com/questions'
  ]
  
  working_url = nil
  
  urls.each do |url|
    puts "\nTesting: #{url}"
    driver.get(url)
    sleep(2)
    
    title = driver.title
    puts "  Title: #{title}"
    
    if !title.include?('not found') && !title.include?('404')
      puts "  ✓ Page exists"
      
      # Look for any posts or questions
      post_elements = driver.find_elements(css: 'div[class*="post"], div[class*="question"], article, .board-item')
      puts "  Found #{post_elements.size} potential post elements"
      
      if post_elements.size > 0
        working_url = driver.current_url
        puts "  ✓ Found posts at: #{working_url}"
        
        # Check for links
        links = driver.find_elements(css: 'a[href*="oppadu.com"]')
        board_links = links.select { |link| 
          href = link.attribute('href')
          text = link.text
          (href.include?('board') || href.include?('community') || 
           text.include?('질문') || text.include?('게시')) rescue false
        }
        
        if board_links.any?
          puts "\n  Found board/community links:"
          board_links.first(5).each do |link|
            puts "    - #{link.text}: #{link.attribute('href')}"
          end
        end
      end
    else
      puts "  ✗ Page not found"
    end
  end
  
  # If we found a working URL, explore it
  if working_url
    puts "\n\nExploring working URL: #{working_url}"
    driver.get(working_url)
    sleep(2)
    
    # Find all class names that might be posts
    all_divs = driver.find_elements(css: 'div')
    post_classes = all_divs.map { |div| div.attribute('class') }
                          .compact
                          .select { |cls| cls.include?('post') || cls.include?('item') || cls.include?('board') }
                          .uniq
                          .first(10)
    
    if post_classes.any?
      puts "\nPotential post classes found:"
      post_classes.each { |cls| puts "  - #{cls}" }
    end
  end
  
rescue => e
  puts "\n❌ Error: #{e.message}"
ensure
  driver&.quit
end

puts "\n✅ Search complete!"