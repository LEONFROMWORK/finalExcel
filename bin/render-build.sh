#!/usr/bin/env bash
# exit on error
set -o errexit

# Generate a dummy secret key for build process
export SECRET_KEY_BASE=${SECRET_KEY_BASE:-$(openssl rand -hex 64)}
echo "🔑 SECRET_KEY_BASE is set"

# Install dependencies
echo "📦 Installing dependencies..."
bundle install
npm install

# Skip asset precompilation - let Rails handle it at runtime
echo "⏭️ Skipping asset precompilation (will be done at runtime)"

# Run database migrations
echo "🗄️ Running database migrations..."
bundle exec rails db:migrate

echo "✅ Build completed successfully!"