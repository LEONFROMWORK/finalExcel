# Resilient Web Scraping Architecture

This document describes the comprehensive resilient web scraping system implemented for the Excel Unified application based on research from authoritative sources including Martin Fowler's Circuit Breaker pattern, AWS's exponential backoff guidelines, and Scrapy's AutoThrottle algorithm.

## Overview

The resilient scraping system implements multiple layers of fault tolerance to handle various failure modes:

1. **Circuit Breaker Pattern** - Prevents cascading failures
2. **Exponential Backoff with Jitter** - Intelligent retry mechanism
3. **Auto-Throttle Algorithm** - Dynamic request rate adjustment
4. **Multi-level Fallback System** - Graceful degradation

## Implementation Details

### 1. Circuit Breaker Pattern (`ResilientScraper`)

Based on the circuit breaker pattern described by Martin Fowler and implemented in production systems like Netflix's Hystrix.

```ruby
class ResilientScraper
  # Circuit states: closed → open → half-open → closed
  
  # Key settings:
  circuit_failure_threshold: 5    # Failures before opening
  circuit_timeout: 60            # Seconds to keep open
  circuit_volume_threshold: 5    # Min requests before evaluating
```

**How it works:**
- Monitors failure rates over a rolling window
- Opens circuit when failure rate exceeds threshold
- Enters half-open state after timeout to test recovery
- Closes circuit on successful request in half-open state

### 2. Exponential Backoff with Jitter

Implements AWS-recommended exponential backoff strategy to prevent thundering herd problems.

```ruby
def calculate_backoff(retry_count)
  backoff = [@options[:backoff_base] ** retry_count, @options[:backoff_max]].min
  
  if @options[:backoff_jitter]
    # Add random jitter (±25%)
    jitter = backoff * 0.25
    backoff = backoff + (rand * 2 * jitter - jitter)
  end
  
  backoff
end
```

**Benefits:**
- Spreads retry attempts over time
- Reduces server load during recovery
- Prevents synchronized retry storms

### 3. Auto-Throttle Algorithm

Inspired by Scrapy's AutoThrottle, dynamically adjusts request delays based on server response times.

```ruby
def update_throttle(latency)
  # Calculate target delay: latency / target_concurrency
  avg_latency = @latencies.sum / @latencies.size.to_f
  target_delay = avg_latency / @options[:target_concurrency]
  
  # Smooth adjustment (average of current and target)
  @current_delay = (@current_delay + target_delay) / 2.0
  
  # Apply bounds
  @current_delay = [[@current_delay, @options[:min_delay]].max, @options[:max_delay]].min
end
```

**Algorithm:**
- If server needs N seconds to respond, send requests every N/concurrency seconds
- Maintains rolling window of recent latencies
- Smoothly adjusts delays to prevent oscillation

### 4. Multi-Level Fallback System

Implements graceful degradation through multiple collection methods:

```
Primary: Selenium WebDriver (full JavaScript support)
    ↓ (timeout/failure)
Secondary: Lightweight HTTP (faster, no JS)
    ↓ (failure)
Tertiary: Nokogiri scraping (most basic)
    ↓ (circuit open)
Fallback: Cached data or queued for later
```

## Usage Example

```ruby
# Initialize resilient collector
collector = ResilientOppaduCollector.new

# Collect with full resilience
result = collector.collect_data(20)

# Check circuit state
puts result[:circuit_state] # :closed, :open, or :half_open
```

## Configuration

### Per-Platform Settings

Each platform can have customized resilience settings:

```ruby
# Conservative for rate-limited sites
oppadu_settings = {
  circuit_failure_threshold: 3,
  target_concurrency: 1,
  min_delay: 1.0,
  max_delay: 15
}

# Aggressive for robust APIs
stackoverflow_settings = {
  circuit_failure_threshold: 10,
  target_concurrency: 5,
  min_delay: 0.1,
  max_delay: 5
}
```

## Monitoring and Observability

The system provides detailed metrics:

- Circuit breaker state transitions
- Request latencies and success rates
- Retry attempts and backoff delays
- Auto-throttle delay adjustments

## Best Practices

1. **Start Conservative**: Begin with low concurrency and adjust based on observed performance
2. **Monitor Circuit States**: Alert when circuits open frequently
3. **Use Appropriate Timeouts**: Balance between giving up too early and wasting resources
4. **Cache Aggressively**: Reduce load on both your system and target servers
5. **Respect robots.txt**: Always check and follow site policies

## Future Enhancements

1. **Distributed Circuit Breakers**: Share state across multiple workers
2. **Predictive Throttling**: Use ML to predict optimal request rates
3. **Request Prioritization**: Queue and prioritize requests during degraded states
4. **Advanced Monitoring**: Integration with APM tools like DataDog or New Relic

## References

- [Martin Fowler - Circuit Breaker](https://martinfowler.com/bliki/CircuitBreaker.html)
- [AWS - Exponential Backoff and Jitter](https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/)
- [Scrapy - AutoThrottle](https://docs.scrapy.org/en/latest/topics/autothrottle.html)
- [Netflix - Hystrix](https://github.com/Netflix/Hystrix)

## Conclusion

This resilient scraping architecture ensures reliable data collection even when facing:
- Transient network failures
- Rate limiting
- Server overload
- Partial outages

The combination of circuit breakers, intelligent retries, and dynamic throttling creates a robust system that respects target servers while maximizing data collection success rates.