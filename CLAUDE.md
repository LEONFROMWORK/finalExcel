# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an Excel Unified application built with:
- **Backend**: Rails 8.0.2 with PostgreSQL database
- **Frontend**: Vue.js 3 with Vite, Vue Router, and Pinia for state management
- **Styling**: Tailwind CSS
- **Authentication**: Devise with OAuth (Google OAuth2)
- **Vector Database**: pgvector with neighbor gem for similarity search

## Key Commands

### Development
```bash
# Start all development servers (Rails, Vite, Tailwind)
cd rails-app && bin/dev

# Install dependencies
cd rails-app && bundle install
cd rails-app && npm install

# Database setup
cd rails-app && bin/rails db:create db:migrate

# Run Rails console
cd rails-app && bin/rails console

# Linting and code quality
cd rails-app && bin/rubocop
cd rails-app && bin/brakeman
```

### Common Rails Tasks
```bash
# Generate migrations
cd rails-app && bin/rails generate migration <MigrationName>

# Run specific rake task
cd rails-app && bin/rails <task_name>

# Asset compilation
cd rails-app && bin/rails assets:precompile
```

## Architecture

### Domain-Driven Design Structure
The application follows a domain-driven design pattern with these domains:
- **authentication**: User authentication, OAuth integration, login/registration services
- **excel_analysis**: Excel file processing and analysis features
- **knowledge_base**: Q&A pairs management and search functionality  
- **ai_consultation**: Chat sessions and AI-powered consultations
- **data_pipeline**: Data collection and processing workflows

### Key Architectural Patterns
1. **Repository Pattern**: Each domain has repositories inheriting from `ApplicationRepository`
2. **Service Objects**: Business logic encapsulated in service classes inheriting from `ApplicationService`
3. **Value Objects**: Including `Result` object for standardized responses
4. **Domain Errors**: Custom error handling with `DomainError` base class

### Frontend Structure
- Vue.js components organized by domain under `/app/javascript/domains/`
- Shared components in `/app/javascript/components/`
- Pinia stores for state management
- Vue Router for client-side routing

### API Structure
All API endpoints are namespaced under `/api/v1/` with domain-specific controllers.

## Development Workflow

1. Backend changes should follow the domain structure
2. Use service objects for complex business logic
3. Repository pattern for data access
4. Frontend components should be domain-scoped when possible
5. Use Pinia stores for cross-component state management