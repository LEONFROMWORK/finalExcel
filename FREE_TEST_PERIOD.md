# 🆓 Excel Unified - Free Test Period

## Overview
This deployment is configured for a **3-month free test period** (July 22, 2025 - October 22, 2025).

## What's Included
✅ **Full Access to Core Features:**
- Excel Analysis & Processing
- AI-powered Consultations
- VBA Helper & Error Solutions
- Knowledge Base Search
- Data Collection from Multiple Platforms
- Admin Dashboard (No login required)

## What's Disabled
❌ **Temporarily Disabled:**
- User Registration/Login
- Payment & Credits System
- User Account Management
- Personal Notifications
- Purchase Features

## Admin Access
The admin panel is accessible at `/api/v1/admin/*` without authentication during the test period.

## API Usage
All API endpoints work without authentication. A test user is automatically assigned for all requests:
```json
{
  "id": 1,
  "email": "test@excelunified.com",
  "name": "Test User",
  "credits": 999999
}
```

## Configuration
The test period settings are managed in:
- `config/initializers/free_test_period.rb`
- `config/routes.rb` (commented sections can be re-enabled after test period)

## After Test Period
To enable full features after the test period:
1. Set `free_test_period[:enabled] = false` in the initializer
2. Uncomment authentication routes in `config/routes.rb`
3. Remove authentication bypasses in controllers
4. Deploy the changes

## Notes
- All data collected during the test period will be preserved
- No user data or personal information is collected
- Admin panel shows aggregated statistics only