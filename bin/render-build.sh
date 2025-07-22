#!/usr/bin/env bash
# exit on error
set -o errexit

# Generate a dummy secret key if not provided
if [ -z "$SECRET_KEY_BASE" ]; then
  echo "🔑 Generating dummy SECRET_KEY_BASE for build..."
  export SECRET_KEY_BASE=$(openssl rand -hex 64)
fi

echo "🔧 SECRET_KEY_BASE is set: ${SECRET_KEY_BASE:0:10}..."

# Install dependencies
echo "📦 Installing dependencies..."
bundle install
npm install

# Build assets with the secret key
echo "🏗️ Building assets..."
RAILS_ENV=production SECRET_KEY_BASE=$SECRET_KEY_BASE bundle exec rails assets:precompile
RAILS_ENV=production SECRET_KEY_BASE=$SECRET_KEY_BASE bundle exec rails assets:clean

# Run database migrations
echo "🗄️ Running database migrations..."
bundle exec rails db:migrate

# Seed database if needed (only on first deploy)
# bundle exec rails db:seed

echo "✅ Build completed successfully!"