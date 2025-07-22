# frozen_string_literal: true

namespace :oppadu do
  namespace :selenium do
    desc "Test Selenium Oppadu collector"
    task test: :environment do
      puts "=== Oppadu Selenium Collector Test ==="
      puts "Ruby version: #{RUBY_VERSION}"
      puts "Rails version: #{Rails.version}"

      begin
        # Check if Selenium WebDriver is available
        require "selenium-webdriver"
        puts "✓ Selenium WebDriver loaded"

        # Check Chrome/ChromeDriver availability
        if ENV["RAILWAY_SELENIUM_URL"].present?
          puts "✓ Using remote Selenium: #{ENV['RAILWAY_SELENIUM_URL']}"
        else
          puts "✓ Using local Chrome/ChromeDriver"
          puts "  Note: Requires Chrome and ChromeDriver installed locally"
        end

        # Test basic collection
        puts "\n1. Testing SeleniumOppaduCollector..."
        collector = SeleniumOppaduCollector.new(limit: 1, headless: true)
        result = collector.collect_data

        if result[:success]
          puts "✓ Collector test PASSED"
          puts "  - Collected #{result[:results].size} items"
          puts "  - Collection method: #{result[:collection_method]}"

          if result[:results].any?
            item = result[:results].first
            puts "\n  Sample item:"
            puts "  - Title: #{item[:title]}"
            puts "  - Has answer: #{item[:answer].present?}"
            puts "  - Tags: #{item[:tags].join(', ')}"
          end
        else
          puts "✗ Collector test FAILED: #{result[:error]}"
        end

      rescue LoadError => e
        puts "✗ Failed to load dependencies: #{e.message}"
      rescue => e
        puts "✗ Test failed: #{e.message}"
        puts e.backtrace.first(5)
      end

      puts "\n=== Test Complete ==="
    end

    desc "Collect Oppadu data with Selenium"
    task :collect, [ :limit ] => :environment do |t, args|
      limit = (args[:limit] || 10).to_i

      puts "=== Oppadu Selenium Data Collection ==="
      puts "Collecting #{limit} items..."

      start_time = Time.current

      collector = SeleniumOppaduCollector.new(limit: limit)
      result = collector.collect_data

      elapsed = Time.current - start_time

      if result[:success]
        puts "\n✅ Collection successful!"
        puts "Items collected: #{result[:results].size}"
        puts "Time elapsed: #{elapsed.round(1)} seconds"
        puts "Method: #{result[:collection_method]}"

        if result[:save_status]
          save_status = result[:save_status]
          puts "\n💾 Save status:"
          puts "  - New items: #{save_status[:new_items]}"
          puts "  - Duplicates: #{save_status[:duplicates]}"
          puts "  - Total items: #{save_status[:total_items]}"
        end

        # Show sample
        if result[:results].any?
          puts "\n📝 Sample item:"
          item = result[:results].first
          puts "Title: #{item[:title]}"
          puts "Question: #{item[:question][0..100]}..."
          puts "Answer: #{item[:answer][0..100]}..."
          puts "Tags: #{item[:tags].join(', ')}"
        end
      else
        puts "\n❌ Collection failed!"
        puts "Error: #{result[:error]}"
      end
    end

    desc "Setup Chrome/ChromeDriver locally"
    task setup: :environment do
      puts "=== Chrome/ChromeDriver Setup Guide ==="

      case RUBY_PLATFORM
      when /darwin/
        puts "\n📱 macOS detected"
        puts "\n1. Install Chrome (if not installed):"
        puts "   Download from: https://www.google.com/chrome/"

        puts "\n2. Install ChromeDriver:"
        puts "   brew install chromedriver"

        puts "\n3. Allow ChromeDriver in Security Settings:"
        puts "   xattr -d com.apple.quarantine $(which chromedriver)"

      when /linux/
        puts "\n🐧 Linux detected"
        puts "\n1. Install Chrome:"
        puts "   wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add -"
        puts "   sudo sh -c 'echo \"deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main\" >> /etc/apt/sources.list.d/google.list'"
        puts "   sudo apt-get update"
        puts "   sudo apt-get install google-chrome-stable"

        puts "\n2. Install ChromeDriver:"
        puts "   sudo apt-get install chromium-chromedriver"

      else
        puts "\n💻 Windows detected"
        puts "\n1. Download Chrome from: https://www.google.com/chrome/"
        puts "\n2. Download ChromeDriver from: https://chromedriver.chromium.org/downloads"
        puts "\n3. Add ChromeDriver to PATH"
      end

      puts "\n🐳 Alternative: Use Docker"
      puts "docker run -d -p 4444:4444 selenium/standalone-chrome:latest"
      puts "export RAILWAY_SELENIUM_URL=http://localhost:4444/wd/hub"
    end

    desc "Test with Docker Selenium"
    task docker_test: :environment do
      puts "=== Docker Selenium Test ==="

      # Check if Docker is running
      docker_running = system("docker info > /dev/null 2>&1")
      unless docker_running
        puts "❌ Docker is not running. Please start Docker first."
        exit 1
      end

      # Check if Selenium container is running
      selenium_running = `docker ps --filter "ancestor=selenium/standalone-chrome" --format "{{.Names}}"`.strip

      if selenium_running.empty?
        puts "Starting Selenium container..."
        system("docker run -d --name selenium-chrome -p 4444:4444 -p 7900:7900 selenium/standalone-chrome:latest")
        sleep(5) # Wait for container to start
      else
        puts "✓ Selenium container already running: #{selenium_running}"
      end

      # Set environment variable
      ENV["RAILWAY_SELENIUM_URL"] = "http://localhost:4444/wd/hub"

      puts "\n✓ Selenium URL: #{ENV['RAILWAY_SELENIUM_URL']}"
      puts "✓ VNC viewer available at: http://localhost:7900 (password: secret)"

      # Run test
      Rake::Task["oppadu:selenium:test"].invoke
    end
  end
end
