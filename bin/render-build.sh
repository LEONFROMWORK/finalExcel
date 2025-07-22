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

# Create empty asset manifest to prevent Rails from trying to compile assets
echo "📄 Creating empty asset manifest..."
mkdir -p public/assets
echo '{"files":{},"assets":{}}' > public/assets/.sprockets-manifest-$(openssl rand -hex 16).json

# Run database migrations
if [ -n "$DATABASE_URL" ]; then
  echo "🗄️ Running database migrations..."
  RAILS_PRECOMPILING=true bundle exec rails db:migrate
else
  echo "⚠️ Skipping migrations (DATABASE_URL not set)"
fi

echo "✅ Build completed successfully!"