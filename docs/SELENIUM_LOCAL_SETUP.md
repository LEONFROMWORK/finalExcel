# Selenium Local Setup Guide

## Prerequisites

### macOS

1. **Install Chrome** (if not already installed):
   ```bash
   # Check if Chrome is installed
   ls /Applications/ | grep -i chrome
   
   # If not installed, download from:
   # https://www.google.com/chrome/
   ```

2. **Install ChromeDriver**:
   ```bash
   # Using Homebrew
   brew install chromedriver
   
   # Or download manually from:
   # https://chromedriver.chromium.org/downloads
   ```

3. **Allow ChromeDriver in Security Settings** (macOS):
   ```bash
   # If you get "chromedriver cannot be opened because the developer cannot be verified"
   xattr -d com.apple.quarantine $(which chromedriver)
   ```

### Linux (Ubuntu/Debian)

```bash
# Install Chrome
wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
sudo sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list'
sudo apt-get update
sudo apt-get install google-chrome-stable

# Install ChromeDriver
sudo apt-get install chromium-chromedriver
```

### Windows

1. Download Chrome from https://www.google.com/chrome/
2. Download ChromeDriver from https://chromedriver.chromium.org/downloads
3. Add ChromeDriver to PATH

## Testing Selenium Setup

### 1. Basic Selenium Test

```ruby
# test_selenium_basic.rb
require 'selenium-webdriver'

driver = Selenium::WebDriver.for :chrome
driver.get "https://www.google.com"
puts "Title: #{driver.title}"
driver.quit
```

### 2. Headless Mode Test

```ruby
# test_selenium_headless.rb
require 'selenium-webdriver'

options = Selenium::WebDriver::Chrome::Options.new
options.add_argument('--headless')
options.add_argument('--disable-gpu')
options.add_argument('--no-sandbox')

driver = Selenium::WebDriver.for :chrome, options: options
driver.get "https://www.google.com"
puts "Title: #{driver.title}"
driver.quit
```

## Common Issues

### Issue: "chromedriver executable needs to be in PATH"

**Solution**:
```bash
# Find chromedriver location
which chromedriver

# Add to PATH (add to ~/.bashrc or ~/.zshrc)
export PATH=$PATH:/usr/local/bin/chromedriver
```

### Issue: "Chrome version mismatch"

**Solution**:
1. Check Chrome version: `google-chrome --version`
2. Download matching ChromeDriver version
3. Replace existing ChromeDriver

### Issue: "Chrome crashes in Docker/CI"

**Solution**: Add these options:
```ruby
options.add_argument('--headless')
options.add_argument('--no-sandbox')
options.add_argument('--disable-dev-shm-usage')
options.add_argument('--disable-gpu')
```

## Running Oppadu Collector Locally

### With Selenium (Recommended)

```bash
# Test Selenium collector
ruby tmp/test_selenium_oppadu.rb

# Run through rake task
bundle exec rake "platform_collector:collect[oppadu,5]"
```

### With Ferrum (Alternative)

```bash
# Ferrum uses Chrome but doesn't need ChromeDriver
bundle exec rake oppadu:ferrum:test
```

## Environment Variables for Local Development

```bash
# .env.local
# Leave RAILWAY_SELENIUM_URL empty for local Chrome
RAILWAY_SELENIUM_URL=

# Optional: Use remote Selenium Grid
# RAILWAY_SELENIUM_URL=http://localhost:4444/wd/hub

# Disable image processing for faster testing
DISABLE_IMAGE_PROCESSING=true
```

## Docker Selenium (Alternative)

If you prefer not to install Chrome/ChromeDriver locally:

```bash
# Run Selenium in Docker
docker run -d -p 4444:4444 -p 7900:7900 \
  --shm-size="2g" \
  selenium/standalone-chrome:latest

# Set environment variable
export RAILWAY_SELENIUM_URL=http://localhost:4444/wd/hub

# Access VNC viewer at http://localhost:7900 (password: secret)
```

## Performance Tips

1. **Reuse driver instance** for multiple operations
2. **Use explicit waits** instead of sleep
3. **Disable images** for faster loading
4. **Run in headless mode** for better performance
5. **Limit concurrent sessions** to avoid resource exhaustion