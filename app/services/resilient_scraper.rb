# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require 'redis'

# Resilient scraper with circuit breaker, exponential backoff, and auto-throttling
class ResilientScraper
  class CircuitOpenError < StandardError; end
  class RateLimitError < StandardError; end
  
  attr_reader :name, :options
  
  DEFAULT_OPTIONS = {
    # Circuit breaker settings
    circuit_failure_threshold: 5,    # Number of failures before opening circuit
    circuit_timeout: 60,             # Seconds to keep circuit open
    circuit_volume_threshold: 5,     # Minimum requests before evaluating
    
    # Exponential backoff settings
    backoff_base: 2,                 # Base for exponential calculation
    backoff_max: 60,                 # Maximum backoff in seconds
    backoff_jitter: true,            # Add random jitter to prevent thundering herd
    
    # Auto-throttle settings
    target_concurrency: 2,           # Target number of concurrent requests
    min_delay: 0.5,                  # Minimum delay between requests
    max_delay: 10,                   # Maximum delay between requests
    
    # Retry settings
    max_retries: 3,                  # Maximum number of retry attempts
    retry_on: [                      # Exceptions to retry on
      Net::ReadTimeout,
      Net::OpenTimeout,
      SocketError,
      Errno::ECONNREFUSED,
      Errno::ETIMEDOUT
    ]
  }.freeze
  
  def initialize(name, options = {})
    @name = name
    @options = DEFAULT_OPTIONS.merge(options)
    @redis = options[:redis] || Redis.new
    @current_delay = @options[:min_delay]
    @latencies = []
    @mutex = Mutex.new
  end
  
  # Main scraping method with full resilience
  def scrape(url, &block)
    # Check circuit breaker first
    check_circuit!
    
    retries = 0
    begin
      start_time = Time.now
      
      # Apply current delay (auto-throttle)
      sleep(@current_delay)
      
      # Execute the scraping logic
      result = if block_given?
        yield url
      else
        default_scrape(url)
      end
      
      # Record success and update throttle
      latency = Time.now - start_time
      record_success(latency)
      update_throttle(latency)
      
      result
      
    rescue *@options[:retry_on] => e
      retries += 1
      
      if retries <= @options[:max_retries]
        # Record failure
        record_failure
        
        # Calculate backoff with jitter
        backoff = calculate_backoff(retries)
        Rails.logger.warn "Scraping failed for #{url}, retry #{retries}/#{@options[:max_retries]} after #{backoff}s: #{e.message}"
        
        sleep(backoff)
        retry
      else
        # Max retries exceeded, record failure and open circuit if needed
        record_failure
        Rails.logger.error "Max retries exceeded for #{url}: #{e.message}"
        raise
      end
    end
  end
  
  # Batch scraping with concurrency control
  def scrape_batch(urls, concurrency: nil)
    concurrency ||= @options[:target_concurrency]
    results = []
    mutex = Mutex.new
    
    threads = urls.map do |url|
      Thread.new do
        begin
          result = scrape(url)
          mutex.synchronize { results << { url: url, result: result, success: true } }
        rescue => e
          mutex.synchronize { results << { url: url, error: e.message, success: false } }
        end
      end
    end
    
    # Process in batches to respect concurrency
    threads.each_slice(concurrency) do |batch|
      batch.each(&:join)
    end
    
    results
  end
  
  # Get current circuit state
  def circuit_state
    if circuit_open?
      :open
    elsif circuit_half_open?
      :half_open
    else
      :closed
    end
  end
  
  # Reset circuit breaker
  def reset_circuit!
    @redis.del(circuit_key(:failures))
    @redis.del(circuit_key(:last_failure))
    @redis.del(circuit_key(:requests))
  end
  
  private
  
  def default_scrape(url)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.read_timeout = 10
    http.open_timeout = 5
    
    request = Net::HTTP::Get.new(uri)
    request['User-Agent'] = 'Mozilla/5.0 (compatible; ResilientScraper/1.0)'
    
    response = http.request(request)
    
    # Check for rate limiting
    if response.code == '429'
      raise RateLimitError, "Rate limited by server"
    end
    
    unless response.code == '200'
      raise "HTTP Error: #{response.code}"
    end
    
    response.body
  end
  
  # Circuit breaker logic
  def check_circuit!
    if circuit_open?
      if Time.now.to_i - last_failure_time > @options[:circuit_timeout]
        # Try half-open state
        Rails.logger.info "Circuit breaker entering half-open state for #{@name}"
      else
        raise CircuitOpenError, "Circuit breaker is open for #{@name}"
      end
    end
  end
  
  def circuit_open?
    failures = @redis.get(circuit_key(:failures)).to_i
    requests = @redis.get(circuit_key(:requests)).to_i
    
    return false if requests < @options[:circuit_volume_threshold]
    
    failure_rate = failures.to_f / requests
    failure_rate > 0.5 && failures >= @options[:circuit_failure_threshold]
  end
  
  def circuit_half_open?
    circuit_open? && Time.now.to_i - last_failure_time > @options[:circuit_timeout]
  end
  
  def last_failure_time
    @redis.get(circuit_key(:last_failure)).to_i
  end
  
  def record_success(latency)
    @redis.incr(circuit_key(:requests))
    @redis.expire(circuit_key(:requests), 60)
    
    # Reset failures on success in half-open state
    if circuit_half_open?
      reset_circuit!
      Rails.logger.info "Circuit breaker closed for #{@name}"
    end
    
    # Record latency for auto-throttle
    @mutex.synchronize do
      @latencies << latency
      @latencies.shift if @latencies.size > 10
    end
  end
  
  def record_failure
    @redis.incr(circuit_key(:failures))
    @redis.incr(circuit_key(:requests))
    @redis.set(circuit_key(:last_failure), Time.now.to_i)
    
    # Expire keys after 60 seconds
    @redis.expire(circuit_key(:failures), 60)
    @redis.expire(circuit_key(:requests), 60)
    @redis.expire(circuit_key(:last_failure), 60)
  end
  
  # Exponential backoff with jitter
  def calculate_backoff(retry_count)
    backoff = [@options[:backoff_base] ** retry_count, @options[:backoff_max]].min
    
    if @options[:backoff_jitter]
      # Add random jitter (±25%)
      jitter = backoff * 0.25
      backoff = backoff + (rand * 2 * jitter - jitter)
    end
    
    backoff
  end
  
  # Auto-throttle based on response latency
  def update_throttle(latency)
    return if @latencies.empty?
    
    @mutex.synchronize do
      # Calculate target delay based on average latency
      avg_latency = @latencies.sum / @latencies.size.to_f
      target_delay = avg_latency / @options[:target_concurrency]
      
      # Smooth adjustment (average of current and target)
      @current_delay = (@current_delay + target_delay) / 2.0
      
      # Apply bounds
      @current_delay = [[@current_delay, @options[:min_delay]].max, @options[:max_delay]].min
      
      Rails.logger.debug "Auto-throttle: latency=#{latency.round(2)}s, avg=#{avg_latency.round(2)}s, delay=#{@current_delay.round(2)}s"
    end
  end
  
  def circuit_key(type)
    "circuit_breaker:#{@name}:#{type}"
  end
end