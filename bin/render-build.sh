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

# Set SECRET_KEY_BASE for asset compilation if not set
if [ -z "$SECRET_KEY_BASE" ]; then
  export SECRET_KEY_BASE=$(ruby -rsecurerandom -e 'puts SecureRandom.hex(64)')
  echo "🔑 Generated temporary SECRET_KEY_BASE for build"
fi

# Precompile assets
echo "🎨 Precompiling assets..."
RAILS_ENV=production bundle exec rails assets:precompile

# Clean old assets
echo "🧹 Cleaning old assets..."
RAILS_ENV=production bundle exec rails assets:clean

# Run database migrations
if [ -n "$DATABASE_URL" ]; then
  echo "🗄️ Running database migrations..."
  bundle exec rails db:migrate
else
  echo "⚠️ Skipping migrations (DATABASE_URL not set)"
fi

echo "✅ Build completed successfully!"