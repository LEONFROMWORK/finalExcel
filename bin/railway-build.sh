#!/bin/bash
set -e

echo "🚀 Starting Railway build process..."

# Install dependencies
echo "📦 Installing Ruby dependencies..."
bundle config set --local deployment 'true'
bundle config set --local without 'development test'
bundle install

# Install JavaScript dependencies
echo "📦 Installing JavaScript dependencies..."
npm install

# Build Vite assets
echo "🏗️  Building Vite assets..."
npm run build || echo "⚠️  Vite build skipped"

# Precompile assets
echo "🎨 Precompiling assets..."
bundle exec rails assets:precompile

# Clean up old assets
echo "🧹 Cleaning old assets..."
bundle exec rails assets:clean

# Run database migrations (will skip if database doesn't exist yet)
echo "🗄️  Running database migrations..."
bundle exec rails db:migrate || echo "⚠️  Skipping migrations (database may not be ready)"

echo "✅ Build complete!"