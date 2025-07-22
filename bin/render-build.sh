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

# Skip Rails asset precompilation - we're using Vite
echo "⏭️ Skipping Rails asset precompilation (using Vite)"

# Run database migrations
if [ -n "$DATABASE_URL" ]; then
  echo "🗄️ Running database migrations..."
  bundle exec rails db:migrate
else
  echo "⚠️ Skipping migrations (DATABASE_URL not set)"
fi

echo "✅ Build completed successfully!"