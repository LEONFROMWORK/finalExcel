class CreateCreditTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :credit_transactions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :transaction_type, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.decimal :balance_after, precision: 10, scale: 2, null: false
      t.decimal :price_paid, precision: 10, scale: 2, default: 0
      t.string :payment_method
      t.string :payment_transaction_id
      t.string :status, null: false, default: 'completed'
      t.datetime :refunded_at
      t.references :related_transaction, foreign_key: { to_table: :credit_transactions }
      t.jsonb :metadata, default: {}
      t.text :notes

      t.timestamps
    end
    
    # 인덱스 추가
    add_index :credit_transactions, :transaction_type
    add_index :credit_transactions, :status
    add_index :credit_transactions, [:user_id, :created_at]
    add_index :credit_transactions, [:user_id, :transaction_type]
    add_index :credit_transactions, :payment_transaction_id
  end
end