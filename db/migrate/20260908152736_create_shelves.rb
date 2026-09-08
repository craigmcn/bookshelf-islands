# ported from community_bookshelf db/migrate (create_shelves)
class CreateShelves < ActiveRecord::Migration[8.1]
  def change
    create_table :shelves do |t|
      t.string :name, null: false
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
    add_index :shelves, [:user_id, :name], unique: true
  end
end
