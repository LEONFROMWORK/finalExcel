class AddMissingFieldsToCollectionRuns < ActiveRecord::Migration[8.0]
  def change
    add_column :collection_runs, :result_summary, :jsonb, default: {}
    add_column :collection_runs, :error_details, :jsonb, default: {}
  end
end