namespace :db do
  desc "Enable pgvector extension"
  task enable_pgvector: :environment do
    ActiveRecord::Base.connection.execute("CREATE EXTENSION IF NOT EXISTS vector")
    puts "pgvector extension enabled"
  rescue => e
    puts "Warning: Could not enable pgvector extension: #{e.message}"
    puts "Make sure you're using Railway's pgvector template or pgvector/pgvector Docker image"
  end
end

# Run this task after db:create
Rake::Task["db:create"].enhance do
  Rake::Task["db:enable_pgvector"].invoke
end
