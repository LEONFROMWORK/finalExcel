#!/usr/bin/env bash
# exit on error
set -o errexit

# Install dependencies
bundle install
npm install

# Set dummy secret for asset compilation
export SECRET_KEY_BASE=${SECRET_KEY_BASE:-$(openssl rand -hex 64)}

# Build assets
bundle exec rails assets:precompile
bundle exec rails assets:clean

# Run database migrations
bundle exec rails db:migrate

# Seed database if needed (only on first deploy)
# bundle exec rails db:seed