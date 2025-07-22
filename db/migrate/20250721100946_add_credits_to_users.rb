class AddCreditsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :credits, :integer, default: 100, null: false
  end
end
