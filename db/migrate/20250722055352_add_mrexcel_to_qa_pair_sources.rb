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
