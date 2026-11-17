class AddHiddenByToEntries < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :entries, :hidden_by_id, :uuid
    add_foreign_key :entries, :users, column: :hidden_by_id, on_delete: :nullify, validate: false
    validate_foreign_key :entries, :users, column: :hidden_by_id
    add_index :entries, :hidden_by_id, where: "hidden_by_id IS NOT NULL", algorithm: :concurrently
  end
end
