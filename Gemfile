source "https://rubygems.org"

ruby "~> 3.3"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.0.2"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS)
gem "rack-cors"

# HTTP requests
gem "httparty"
gem "nokogiri", "~> 1.16", force_ruby_platform: true

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache and Active Job
gem "solid_cache"
gem "solid_queue"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
# gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
# gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"
gem "mini_magick", "~> 4.12"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  
  # .env file support
  gem "dotenv-rails"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # Testing framework
  gem "rspec-rails", "~> 7.1"
  gem "factory_bot_rails", "~> 6.4"
  gem "faker", "~> 3.5"
  gem "shoulda-matchers", "~> 6.4"
end

group :test do
  # Code coverage
  gem "simplecov", require: false
  gem "simplecov-html", require: false

  # Clean database between tests
  gem "database_cleaner-active_record", "~> 2.2"

  # Mock HTTP requests
  gem "webmock", "~> 3.24"
  gem "vcr", "~> 6.3"

  # Time manipulation
  gem "timecop", "~> 0.9"

  # Capybara for integration tests
  gem "capybara", "~> 3.40"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

gem "vite_rails", "~> 3.0"

gem "devise", "~> 4.9"

gem "omniauth", "~> 2.1"
gem "omniauth-google-oauth2", "~> 1.2"
gem "omniauth-rails_csrf_protection", "~> 1.0"

gem "pgvector", "~> 0.3.2"
gem "neighbor", "~> 0.6.0"

# SQLite3 for Pipedata import
gem "sqlite3", "~> 1.4"

# Redis for caching and background jobs
gem "redis", "~> 5.0"
gem "sidekiq", "~> 7.2"
gem "sidekiq-cron", "~> 1.12"

# Image Processing - 3-tier system
# gem "ruby-opencv", "~> 0.0.18" # Image processing for table detection - Skip due to build issues
gem "rtesseract", "~> 3.1"     # Ruby wrapper for Tesseract OCR
gem "ruby-openai", "~> 8.1"    # OpenAI/OpenRouter integration
gem "httpclient", "~> 2.8"     # For image downloading
gem "chunky_png", "~> 1.4"     # Pure Ruby image analysis

# Note: selenium-webdriver is already included in test group (line 86)

# Web scraping
gem "selenium-webdriver", "~> 4.27" # For Railway deployment and Oppadu scraping

gem "playwright-ruby-client", "~> 1.54"
