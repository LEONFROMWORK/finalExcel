#!/usr/bin/env bash
# exit on error
set -o errexit

# Install dependencies
echo "📦 Installing dependencies..."
bundle install
npm install

# Create empty manifest file to skip asset compilation
mkdir -p public/assets
touch public/assets/.sprockets-manifest-$(date +%s).json
echo '{}' > public/assets/.sprockets-manifest-$(date +%s).json

echo "⏭️ Skipped asset precompilation"

# Run database migrations only if DATABASE_URL is set
if [ -n "$DATABASE_URL" ]; then
  echo "🗄️ Running database migrations..."
  bundle exec rails db:migrate
else
  echo "⚠️ Skipping migrations (DATABASE_URL not set)"
fi

echo "✅ Build completed successfully!"