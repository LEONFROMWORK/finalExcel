# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "Seeding database..."

# Create admin user
admin = Authentication::User.find_or_create_by!(email: 'admin@excel-unified.com') do |user|
  user.password = 'admin123456'
  user.name = 'System Admin'
  user.role = 'admin'
end

# Create test user
test_user = Authentication::User.find_or_create_by!(email: 'test@example.com') do |user|
  user.password = 'testpassword123'
  user.name = 'Test User'
  user.role = 'user'
end

puts "Created users:"
puts "  Admin: admin@excel-unified.com / admin123456"
puts "  Test: test@example.com / testpassword123"

puts "Seed completed!"
