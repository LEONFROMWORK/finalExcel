# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require "base64"

##
# Reddit image 403 bypassing service
# Ruby port of Python RedditImageBypasser with comprehensive bypass techniques
#
# Features:
# - Multiple user agent rotation
# - OAuth session management
# - URL alternative generation
# - Session spoofing
# - Proxy header simulation
class RedditImageBypasser
  class RedditBypassError < StandardError; end

  # Latest browser user agents (2025)
  USER_AGENTS = [
    # Chrome latest versions
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36",

    # Firefox latest versions
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:122.0) Gecko/20100101 Firefox/122.0",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:122.0) Gecko/20100101 Firefox/122.0",
    "Mozilla/5.0 (X11; Linux x86_64; rv:122.0) Gecko/20100101 Firefox/122.0",

    # Edge latest version
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36 Edg/121.0.0.0",

    # Safari latest version
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2.1 Safari/605.1.15"
  ].freeze

  # Supported image formats
  SUPPORTED_FORMATS = %w[.jpg .jpeg .png .gif .webp].freeze

  def initialize(reddit_credentials = {})
    @reddit_credentials = reddit_credentials
    @reddit_session = nil
    @session_expires = 0
    @success_stats = {
      total_attempts: 0,
      successful_downloads: 0,
      method_success: {}
    }
    @logger = Rails.logger
  end

  # Main entry point for downloading Reddit images with bypass
  def download_reddit_image_with_bypass(url)
    @success_stats[:total_attempts] += 1

    # Preprocess URL
    cleaned_url = decode_reddit_url(url)
    alternative_urls = get_alternative_reddit_urls(cleaned_url)

    @logger.info "🎯 Reddit image download attempt: #{alternative_urls.size} URLs"

    # Get OAuth session if possible
    oauth_token = get_reddit_oauth_session

    # Try each URL with different methods
    methods = [
      [ :basic_http, method(:download_with_basic_http) ],
      [ :oauth_http, method(:download_with_oauth_http) ],
      [ :session_spoofing, method(:download_with_session_spoofing) ],
      [ :proxy_simulation, method(:download_with_proxy_simulation) ]
    ]

    methods.each do |method_name, method_proc|
      alternative_urls.each do |attempt_url|
        begin
          @logger.debug "  Trying: #{method_name} + #{attempt_url[0..50]}..."

          result = method_proc.call(attempt_url, oauth_token)
          if result && result.bytesize > 1000 # Ensure it's a real image
            @success_stats[:successful_downloads] += 1
            @success_stats[:method_success][method_name] ||= 0
            @success_stats[:method_success][method_name] += 1

            @logger.info "✅ Success! Method: #{method_name}"
            return [ result, method_name.to_s ]
          end

          # Delay to avoid rate limiting
          sleep(rand(0.5..1.5))

        rescue => e
          @logger.debug "  Failed: #{method_name} - #{e.message}"
          next
        end
      end
    end

    @logger.error "❌ All methods failed: #{url}"
    [ nil, "all_failed" ]
  end

  private

  # Decode and clean Reddit URLs
  def decode_reddit_url(url)
    return url unless url

    # HTML entity decoding
    require "cgi"
    url = CGI.unescapeHTML(url)

    # URL decoding
    url = URI.decode_www_form_component(url)

    # Reddit-specific cleaning patterns
    url = url.gsub("amp;s=", "s=")
    url = url.gsub(/amp;/, "&")

    # Remove duplicate protocols
    url = url.gsub(/https?:\/\/https?:\/\//, "https://")

    url
  end

  # Generate alternative URLs from original URL
  def get_alternative_reddit_urls(original_url)
    alternatives = [ original_url ]

    uri = URI.parse(original_url)

    # 1. preview.redd.it → i.redd.it conversion
    if uri.host&.include?("preview.redd.it")
      i_redd_url = original_url.gsub("preview.redd.it", "i.redd.it")
      clean_i_redd = i_redd_url.split("?")[0]
      alternatives.push(i_redd_url, clean_i_redd)
    end

    # 2. external-preview.redd.it → preview.redd.it conversion
    if uri.host&.include?("external-preview.redd.it")
      preview_url = original_url.gsub("external-preview.redd.it", "preview.redd.it")
      alternatives << preview_url
    end

    # 3. Various quality/size parameters
    if original_url.include?("?")
      base_url = original_url.split("?")[0]

      quality_params = [
        "format=png&auto=webp&s=",
        "format=jpg&auto=webp&s=",
        "width=1024&format=png&auto=webp&s=",
        "width=512&format=jpg&auto=webp&s="
      ]

      quality_params.each do |param|
        alternatives << "#{base_url}?#{param}"
      end
    end

    # 4. HTTPS → HTTP fallback
    if original_url.start_with?("https://")
      alternatives << original_url.gsub("https://", "http://")
    end

    alternatives.uniq
  end

  # Get Reddit-specific headers
  def get_reddit_headers(url, oauth_token = nil)
    uri = URI.parse(url)
    user_agent = USER_AGENTS.sample

    headers = {
      "User-Agent" => user_agent,
      "Accept" => "image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8",
      "Accept-Language" => "en-US,en;q=0.9",
      "Accept-Encoding" => "gzip, deflate, br",
      "Cache-Control" => "no-cache",
      "Pragma" => "no-cache",
      "DNT" => "1",
      "Upgrade-Insecure-Requests" => "1",
      "Sec-Fetch-Dest" => "image",
      "Sec-Fetch-Mode" => "no-cors",
      "Sec-Fetch-Site" => "cross-site",
      "Sec-Ch-Ua" => '"Not A(Brand)";v="99", "Google Chrome";v="121", "Chromium";v="121"',
      "Sec-Ch-Ua-Mobile" => "?0",
      "Sec-Ch-Ua-Platform" => '"Windows"'
    }

    # Reddit domain-specific headers
    if uri.host&.include?("reddit")
      headers.merge!({
        "Referer" => "https://www.reddit.com/",
        "Origin" => "https://www.reddit.com"
      })

      # OAuth token for specific endpoints
      if oauth_token && uri.host&.include?("oauth.reddit.com")
        headers["Authorization"] = "Bearer #{oauth_token}"
      end
    elsif uri.host&.include?("redd.it")
      headers.merge!({
        "Referer" => "https://www.reddit.com/",
        "Sec-Fetch-Site" => "same-site"
      })
    end

    headers
  end

  # Get Reddit OAuth session token
  def get_reddit_oauth_session
    return nil unless @reddit_credentials[:client_id] && @reddit_credentials[:client_secret]

    # Use cached session if still valid
    if @reddit_session && Time.current.to_i < @session_expires
      return @reddit_session
    end

    begin
      uri = URI("https://www.reddit.com/api/v1/access_token")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 30

      request = Net::HTTP::Post.new(uri)
      request["User-Agent"] = "ExcelQACollector/1.0 by /u/#{@reddit_credentials[:username] || 'test_user'}"
      request["Authorization"] = "Basic #{get_basic_auth}"
      request.set_form_data("grant_type" => "client_credentials")

      response = http.request(request)

      if response.code == "200"
        data = JSON.parse(response.body)
        @reddit_session = data["access_token"]
        @session_expires = Time.current.to_i + data["expires_in"] - 60
        @logger.info "✅ Reddit OAuth session acquired"
        @reddit_session
      else
        @logger.warn "Reddit OAuth failed: #{response.code}"
        nil
      end

    rescue => e
      @logger.error "Reddit OAuth error: #{e.message}"
      nil
    end
  end

  # Generate Basic auth header for Reddit OAuth
  def get_basic_auth
    credentials = "#{@reddit_credentials[:client_id]}:#{@reddit_credentials[:client_secret]}"
    Base64.strict_encode64(credentials)
  end

  # Basic HTTP download
  def download_with_basic_http(url, oauth_token)
    uri = URI.parse(url)
    headers = get_reddit_headers(url, oauth_token)

    # Random delay
    sleep(rand(0.5..3.0))

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30

    request = Net::HTTP::Get.new(uri)
    headers.each { |key, value| request[key] = value }

    response = http.request(request)

    return response.body if response.code == "200" && response.body.bytesize > 1000
    nil
  end

  # OAuth-enhanced download
  def download_with_oauth_http(url, oauth_token)
    return nil unless oauth_token

    uri = URI.parse(url)
    headers = get_reddit_headers(url, oauth_token)
    headers["Authorization"] = "Bearer #{oauth_token}"

    sleep(rand(0.5..2.0))

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30

    request = Net::HTTP::Get.new(uri)
    headers.each { |key, value| request[key] = value }

    response = http.request(request)

    return response.body if response.code == "200" && response.body.bytesize > 1000
    nil
  end

  # Session spoofing download
  def download_with_session_spoofing(url, oauth_token)
    uri = URI.parse(url)
    headers = get_reddit_headers(url, oauth_token)

    # Fake cookies to simulate session
    fake_cookies = [
      "session_tracker=reddit_#{Time.current.to_i}",
      "eu_cookie_v2=1",
      "session=sess_#{rand(100000..999999)}",
      "csv=2",
      "edgebucket=control_1"
    ].join("; ")

    headers["Cookie"] = fake_cookies

    sleep(rand(0.4..2.5))

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30

    request = Net::HTTP::Get.new(uri)
    headers.each { |key, value| request[key] = value }

    response = http.request(request)

    return response.body if response.code == "200" && response.body.bytesize > 1000
    nil
  end

  # Proxy header simulation download
  def download_with_proxy_simulation(url, oauth_token)
    uri = URI.parse(url)
    headers = get_reddit_headers(url, oauth_token)

    # Add proxy headers
    headers.merge!({
      "X-Forwarded-For" => "#{rand(1..255)}.#{rand(1..255)}.#{rand(1..255)}.#{rand(1..255)}",
      "X-Real-IP" => "#{rand(1..255)}.#{rand(1..255)}.#{rand(1..255)}.#{rand(1..255)}",
      "X-Forwarded-Proto" => "https"
    })

    sleep(rand(0.2..5.0))

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30

    request = Net::HTTP::Get.new(uri)
    headers.each { |key, value| request[key] = value }

    response = http.request(request)

    return response.body if response.code == "200" && response.body.bytesize > 1000
    nil
  end

  public

  # Get current success rate
  def get_success_rate
    return 0.0 if @success_stats[:total_attempts] == 0
    (@success_stats[:successful_downloads].to_f / @success_stats[:total_attempts]) * 100
  end

  # Get detailed statistics
  def get_detailed_stats
    {
      success_rate: get_success_rate,
      total_attempts: @success_stats[:total_attempts],
      successful_downloads: @success_stats[:successful_downloads],
      method_breakdown: @success_stats[:method_success]
    }
  end
end
