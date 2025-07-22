#!/usr/bin/env bash
# exit on error
set -o errexit

# Install dependencies
echo "📦 Installing dependencies..."
bundle install
npm install

# Build Vite assets
echo "🏗️ Building Vite assets..."
npm run build

# Precompile assets
echo "🎨 Precompiling assets..."
bundle exec rails assets:precompile

# Clean old assets
echo "🧹 Cleaning old assets..."
bundle exec rails assets:clean

# Run database migrations
if [ -n "$DATABASE_URL" ]; then
  echo "🗄️ Running database migrations..."
  bundle exec rails db:migrate
else
  echo "⚠️ Skipping migrations (DATABASE_URL not set)"
fi

echo "✅ Build completed successfully!"