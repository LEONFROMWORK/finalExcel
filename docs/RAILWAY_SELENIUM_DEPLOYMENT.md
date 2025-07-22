# Railway Selenium Deployment Guide

## Overview

This guide explains how to deploy the Excel Unified app with Selenium support for Oppadu web scraping on Railway.

## Architecture

```
┌─────────────────┐     ┌──────────────────┐
│   Rails App     │────▶│ Selenium Service │
│  (Main Service) │     │  (Chrome Driver) │
└─────────────────┘     └──────────────────┘
         │
         ▼
┌─────────────────┐
│ Oppadu Website  │
└─────────────────┘
```

## Deployment Steps

### 1. Deploy Main Application

```bash
# In your project directory
railway login
railway link
railway up
```

### 2. Add Selenium Service

```bash
# Add Selenium standalone Chrome service
railway add

# When prompted, select:
# - Docker Image
# - Image: selenium/standalone-chrome:latest
# - Service name: selenium
```

### 3. Configure Environment Variables

```bash
# Set Selenium URL for production
railway variables set RAILWAY_SELENIUM_URL='${{RAILWAY_PRIVATE_DOMAIN}}:4444/wd/hub'

# Verify configuration
railway variables
```

### 4. Configure railway.json (Alternative to railway.toml)

```json
{
  "$schema": "https://railway.app/railway.schema.json",
  "build": {
    "builder": "NIXPACKS",
    "buildCommand": "bundle install && bundle exec rake assets:precompile"
  },
  "deploy": {
    "startCommand": "bundle exec puma -C config/puma.rb",
    "healthcheckPath": "/health",
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 10
  }
}
```

## Environment Variables

### Required for Selenium Integration

```bash
RAILWAY_SELENIUM_URL=http://selenium.railway.internal:4444/wd/hub
```

### Optional Performance Tuning

```bash
# Selenium configuration
SE_NODE_MAX_SESSIONS=5
SE_NODE_SESSION_TIMEOUT=300
SE_SCREEN_WIDTH=1366
SE_SCREEN_HEIGHT=768

# Disable image loading for faster scraping
DISABLE_IMAGE_PROCESSING=true
```

## Testing the Deployment

### 1. Check Selenium Health

```bash
# SSH into your Railway app
railway run bash

# Test Selenium connection
curl -s http://selenium.railway.internal:4444/wd/hub/status | jq
```

### 2. Test Oppadu Collection

```bash
# Run collection task
railway run bundle exec rake "platform_collector:collect[oppadu,5]"
```

### 3. Monitor Logs

```bash
# View app logs
railway logs

# View Selenium logs
railway logs --service=selenium
```

## Troubleshooting

### Issue: Selenium Connection Failed

**Symptom**: `Failed to connect to Selenium`

**Solution**:
1. Verify Selenium service is running: `railway status`
2. Check internal DNS: `nslookup selenium.railway.internal`
3. Use correct URL format: `http://selenium.railway.internal:4444/wd/hub`

### Issue: Timeout Errors

**Symptom**: `Selenium::WebDriver::Error::TimeoutError`

**Solution**:
1. Increase timeout in SeleniumOppaduCollector
2. Add more memory to Selenium service
3. Disable image loading: `DISABLE_IMAGE_PROCESSING=true`

### Issue: Chrome Crashes

**Symptom**: `Chrome failed to start: crashed`

**Solution**:
1. Ensure `--no-sandbox` flag is set
2. Add `--disable-dev-shm-usage`
3. Increase service memory allocation

## Performance Optimization

### 1. Resource Allocation

```toml
# In Railway dashboard, set for Selenium service:
Memory: 2GB
CPU: 1 vCPU
```

### 2. Concurrent Limits

```ruby
# In app configuration
MAX_SELENIUM_SESSIONS = 3  # Don't exceed SE_NODE_MAX_SESSIONS
```

### 3. Caching Strategy

```ruby
# Cache Oppadu data for 24 hours
Rails.cache.fetch("oppadu_data_#{Date.current}", expires_in: 24.hours) do
  collector.collect_data(50)
end
```

## Monitoring

### 1. Add Health Check Endpoint

```ruby
# app/controllers/health_controller.rb
class HealthController < ApplicationController
  def show
    selenium_healthy = check_selenium_health
    
    render json: {
      status: selenium_healthy ? 'healthy' : 'degraded',
      services: {
        rails: 'healthy',
        selenium: selenium_healthy ? 'healthy' : 'unhealthy'
      }
    }
  end
  
  private
  
  def check_selenium_health
    uri = URI("#{ENV['RAILWAY_SELENIUM_URL']}/status")
    response = Net::HTTP.get_response(uri)
    response.code == '200'
  rescue
    false
  end
end
```

### 2. Add Metrics Collection

```ruby
# Track collection performance
Rails.logger.info({
  event: 'oppadu_collection',
  method: 'selenium',
  duration: duration,
  items_collected: results.size,
  success: true
}.to_json)
```

## Cost Optimization

### Estimated Monthly Costs

- Rails App: ~$5-10 (Hobby plan)
- Selenium Service: ~$5-10 (1GB RAM)
- Total: ~$10-20/month

### Cost Saving Tips

1. **Schedule Collections**: Run during off-peak hours
2. **Batch Processing**: Collect multiple pages at once
3. **Smart Caching**: Cache results for 24 hours
4. **Conditional Processing**: Only collect new posts

## Security Considerations

1. **Network Isolation**: Selenium only accessible within Railway network
2. **No Public Exposure**: Selenium port not exposed to internet
3. **Authentication**: Add basic auth if needed:

```ruby
# Add to SeleniumOppaduCollector
def setup_selenium_driver
  if ENV['SELENIUM_AUTH_USER'].present?
    @selenium_url = @selenium_url.sub('://', "://#{ENV['SELENIUM_AUTH_USER']}:#{ENV['SELENIUM_AUTH_PASS']}@")
  end
  # ... rest of setup
end
```

## Fallback Strategy

The application implements a 3-tier fallback system:

```
1. Selenium (Railway) ─── Fails ──▶ 2. Ferrum (Local) ─── Fails ──▶ 3. Nokogiri
         │                                    │                            │
         ▼                                    ▼                            ▼
   Best Success Rate                  Development Only              Last Resort
      (~95%)                              (~90%)                      (~10%)
```

## Maintenance

### Weekly Tasks
- Monitor Selenium memory usage
- Review collection success rates
- Update Chrome version if needed

### Monthly Tasks
- Analyze cost trends
- Optimize collection frequency
- Review and clean cached data

## Support

For issues specific to Railway deployment:
- Railway Discord: https://discord.gg/railway
- Railway Docs: https://docs.railway.app

For Selenium issues:
- SeleniumHQ Docs: https://www.selenium.dev/documentation/
- Chrome DevTools Protocol: https://chromedevtools.github.io/devtools-protocol/