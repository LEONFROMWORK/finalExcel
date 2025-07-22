#!/usr/bin/env ruby
# Add MrExcel to allowed sources

puts "Adding 'mrexcel' to allowed sources..."

# Generate migration
migration_name = "add_mrexcel_to_qa_pair_sources"
timestamp = Time.now.strftime("%Y%m%d%H%M%S")
migration_file = "db/migrate/#{timestamp}_#{migration_name}.rb"

migration_content = <<~RUBY
  class AddMrexcelToQaPairSources < ActiveRecord::Migration[8.0]
    def up
      # Update the check constraint to include 'mrexcel'
      execute <<-SQL
        ALTER TABLE qa_pairs DROP CONSTRAINT IF EXISTS qa_pairs_source_check;
        ALTER TABLE qa_pairs ADD CONSTRAINT qa_pairs_source_check 
        CHECK (source IN ('stackoverflow', 'reddit', 'oppadu', 'mrexcel', 'user_generated', 'excel_analysis'));
      SQL
    end

    def down
      # Revert to original constraint
      execute <<-SQL
        ALTER TABLE qa_pairs DROP CONSTRAINT IF EXISTS qa_pairs_source_check;
        ALTER TABLE qa_pairs ADD CONSTRAINT qa_pairs_source_check 
        CHECK (source IN ('stackoverflow', 'reddit', 'oppadu', 'user_generated', 'excel_analysis'));
      SQL
    end
  end
RUBY

File.write(migration_file, migration_content)
puts "Created migration: #{migration_file}"

# Update the model
model_path = "app/domains/knowledge_base/models/qa_pair.rb"
model_content = File.read(model_path)

# Update the validation
updated_content = model_content.gsub(
  "in: %w[stackoverflow reddit oppadu user_generated excel_analysis]",
  "in: %w[stackoverflow reddit oppadu mrexcel user_generated excel_analysis]"
)

File.write(model_path, updated_content)
puts "Updated model validation"

puts "\nNow run: bin/rails db:migrate"