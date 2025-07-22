#!/usr/bin/env ruby
# Create a system user for error patterns

# Ensure the model is loaded
require_relative 'app/domains/authentication/models/user'

begin
  user = Authentication::User.find_or_create_by!(email: 'system@example.com') do |u|
    u.password = 'password123'
  end
  puts "User created/found: #{user.email}"
rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace.first(5)
end